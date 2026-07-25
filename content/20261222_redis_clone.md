---
title: "Writing a basic redis clone in Go from scratch"
date: 2022-12-22
author: "Hanif Bin Ariffin"
---

# Introduction

In this tutorial, we will write a basic `redis` server that is capable of responding to valid RESP requests.
In case you are not familiar with what `redis` is, check out their [website](https://redis.io/).
Needless to say, it is an extremely popular caching mechanism that is used everywhere.

However, you might think to yourself that implementing one is a daunting task.
I am going to show you that (minus all the critical performance requirements), a `redis` server is in fact pretty simple.
I believe implementing one is a great way to learn about programming.
Plus, it also makes you appreciate the engineering challenges of developing a _good_ one.

The full source code is available in this [repository](https://github.com/hbina/redis_clone).

Let's begin.

# Introduction to REdiS Protocol (RESP)

Before we can interact with a `redis` application, we need to look at the protocol that it understand.
A `redis` application talks using a protocol called RESP.
The protocol is quite simple, the [reference documentation](https://redis.io/docs/reference/protocol-spec/) fits within a reasonably short HTML page (with examples!).

So, in summary, a RESP object is one of 5 things:

1. A simple string.
2. An error string.
3. An integer value.
4. A bulk string.
5. An array where each element is another RESP object.

A RESP object begins with a flag byte and uses `\r\n` (will be referred to as CRLF) as a separator or terminator.
For example, a RESP simple string looks like `+PING\r\n`.
Where,

1. the first byte (`+`) indicates the type of data, in this case its a simple string
2. `PING` is the payload,
3. and ends with a CRLF (`\r\n`).

Let's take a look at each object.

## Simple Strings

As we have seen above, a simple string:

1. Starts with the `+` flag byte.
2. Followed by the payload (which are just bytes).
3. Ends with the CRLF.

Now you might be wondering, what if there are `\r\n` within the payload?
For example, something like `+PINGTHEN\r\nPONG\r\n` where `PINGTHEN\r\nPONG` is intended to be the payload.
Well, simple string simply cannot handle this particular use case.
For payloads that may contain `\r\n` consecutively, one should use bulk strings instead.

## Error Strings

Error string is exactly the same as a simple string except that:

1. It begins with the `-` as the flag byte.
2. It is supposed to be treated as an error message by the client.

## Integers

A RESP integer:

1. Starts with `:` as the flag byte.
2. Followed by the decimal string representation of that number.
3. Ends with the CRLF.

For example, `:12354\r\n` is a valid integer.
The specification does not specify the limit of these integer.
However, most implementations will limit it to whatever the host machine can handle.
Note that it ONLY supports decimal representation.
So something like, `:0xffff\r\n` is not a valid RESP integer.

## Bulk Strings

A bulk string is a little bit more complicated.
It,

1. Starts with `$` as the flag byte.
2. Followed by a decimal string representation of the length of the string.
3. Followed by the CRLF.
4. Followed by the payload.
5. Then another final CRLF.

Therefore, a ping reponse (like above) will look like `$4\r\nPING\r\n` instead.

This might seem like a redundant object type since we already have simple strings.
Why do we need another string representation?
Well, for one, because a bulk string comes with the length of the payload, it can safely have the CRLF as the payload.
Another is a matter of performance.
Consider what happens if you send/receive a very, very, very long string like a 4MB (33554432 bytes) text of a long novel.
If represented as a simple string, the RESP parser would have to iterate over 33554432 bytes looking for the CRLF.
However, using bulk strings, they can just check the length of the byte they receive and wait until there are 33554432 bytes.

## Arrays

A RESP array is represented simply as multiple RESP objects.
It,

1. Begins with the `*` flag byte.
2. Then the number of elements in the array (also in decimal string representation),
3. Then the CRLF,
4. Then N number of RESP objects.

Visually it looks like this,

```
*<length-of-array>\r\n<resp><resp><resp>...
```

For example, a RESP array that consists of 2 simple strings, PING and PONG, looks like,

```
*2\r\n+PING\r\n+PONG\r\n
```

It is also possible to have multidimensional RESP arrays.
Let's try to represent something like `[["hello","world"], ["goodbye", "world"]]` as a RESP array.

1. First, we need the `*` byte to mark this as a RESP array.
   So we have `*`.
2. And we have an array of length 2.
   Now we have `*2`.
3. Then we need the CRLF to mark the end of the length.
   Now we have `*2\r\n`.
4. Now we have another RESP of length 2...so we just do the same!
   Now we have `*2\r\n*2\r\n`.
5. This first inner array contains 2 simple strings `hello` and `world`.
   Now we have `*2\r\n*2\r\n+hello\r\n+world\r\n`.
6. Then we have another inner array that contains 2 simple strings of `goodbye` and `world`.
   Now we have `*2\r\n*2\r\n+hello\r\n+world\r\n*2\r\n+hello\r\n+world\r\n`

And that's it! That's the entire RESP protocol.
We can now try to implement one.

## Additional Notes on Bulk String and Array

There's an additional use for bulk strings and arrays, they can be used to represent the nil (or null) value.
Let's say our Redis server stores an empty set, what should the server return when we query for its member?
We could return an error saying "sorry, but it's empty!" but then the client would have to manually parse and differentiate different kind of error messages.
In my opinion, this is bad API design.

So, here's where the length component of bulk strings and array come in handy.
There are 2 kinds of null value in RESP: nil bulk string and nil arrays.
They are represented as `$-1\r\n` and `*-1\r\n` respectively.

As far as I know, they can be any negative number.
I don't think the particular value have any meaning at all.

# Implementation of RESP in Golang

If you look at the description of RESP above, you might notice that we deal a lot with data that ends with CRLF.
So it will be very useful to have a helper function that takes some bytes and return the:

1. Bytes up to the CRLF
2. The leftover bytes beginning from the CRLF to the end
3. Whether or not this is valid

```golang
// resp.go
func TakeBytesUntilClrf(in []byte) ([]byte, []byte, bool) {
	// If we have empty data, we can't do anything so just return false
	if len(in) == 0 {
		return []byte{}, []byte{}, false
	}

	idx := 0
	// Keep incrementing the index until we have nothing left or we found a CRLF
	for len(in) > idx+1 && !(in[idx] == '\r' && in[idx+1] == '\n') {
		idx++
	}

	// Now check again why did we stop looping, is it because we found a CRLF or because we ran out of data?
	if len(in) > idx+1 && in[idx] == '\r' && in[idx+1] == '\n' {
		// We found the CRLF, return the result
		return in[:idx], in[idx+2:], true
	} else {
		// We didn't find the CRLF, return false
		return in, []byte{}, false
	}
}
```

## Representation of RESP in Golang

First, we need some way to represent RESP as an interface,

```golang
// resp.go
type Resp interface {
	// Converts into their byte representation.
	// For example a RESP simple string that contains "hello" will convert into `+hello\r\n`
	AsBytes() []byte

	// static FromBytes([]byte) Resp
}
```

The `AsBytes` function here is important because we will be dealing with networking which only understand bytes.
Thus, we want a consistent way to convert from our internal Go's representation into the network stream.

### Simple String

```golang
// resp.go
type RespSimpleString struct {
	inner string
}

func (rs *RespSimpleString) AsBytes() []byte {
	result := make([]byte, 0, 1+len(rs.inner)+2)
	result = append(result, []byte("+")...)
	result = append(result, []byte(rs.inner)...)
	result = append(result, []byte("\r\n")...)
	return result
}

func RssFromBytes(in []byte) (Resp, []byte) {
	if len(in) == 0 {
		return nil, []byte{}
	} else if in[0] == '+' {
		// For simple strings, we simply get everything from the byte after '+' until CRLF
		str, leftover, ok := TakeBytesUntilClrf(in[1:])

		if !ok {
			return nil, []byte{}
		}

		rs := RespSimpleString{
			inner: string(str),
		}

		return &rs, leftover
	} else {
		return nil, []byte{}
	}
}
```

### Error String

```golang
// resp.go
type RespErrorString struct {
	inner string
}

func (rs *RespErrorString) AsBytes() []byte {
	result := make([]byte, 0, 1+len(rs.inner)+2)
	result = append(result, []byte("-")...)
	result = append(result, []byte(rs.inner)...)
	result = append(result, []byte("\r\n")...)
	return result
}

func ResFromBytes(in []byte) (Resp, []byte) {
	if len(in) == 0 {
		return nil, []byte{}
	} else if in[0] == '-' {
		// Similar to error strings
		str, leftover, ok := TakeBytesUntilClrf(in[1:])

		if !ok {
			return nil, []byte{}
		}

		rs := RespErrorString{
			inner: string(str),
		}

		return &rs, leftover
	} else {
		return nil, []byte{}
	}
}
```

### Integer

```golang
// resp.go
type RespInteger struct {
	inner int
}

func (rs *RespInteger) AsBytes() []byte {
	v := fmt.Sprintf("%d", rs.inner)
	result := make([]byte, 0, 1+len(v)+2)
	result = append(result, []byte(":")...)
	result = append(result, []byte(v)...)
	result = append(result, []byte("\r\n")...)
	return result
}

func RiFromBytes(in []byte) (Resp, []byte) {
	if len(in) == 0 {
		return nil, []byte{}
	} else if in[0] == ':' {
		// Integer is a little bit interesting, we get everything until CRLF
		str, leftover, ok := TakeBytesUntilClrf(in[1:])

		if !ok {
			return nil, []byte{}
		}

		// Then we try to parse the bytes as a 32-bit integer
		val, err := strconv.ParseInt(string(str), 10, 32)

		if err != nil {
			return nil, []byte{}
		}

		rs := RespInteger{
			inner: int(val),
		}

		return &rs, leftover
	} else {
		return nil, []byte{}
	}
}
```

### Bulk String

```golang
// resp.go
type RespBulkString struct {
	inner string
}

func (rs *RespBulkString) AsBytes() []byte {
	a := fmt.Sprintf("%d", len(rs.inner))
	b := []byte(rs.inner)
	result := make([]byte, 0, 1+len(a)+2+len(b)+2)
	result = append(result, []byte("$")...)
	result = append(result, []byte(a)...)
	result = append(result, []byte("\r\n")...)
	result = append(result, b...)
	result = append(result, []byte("\r\n")...)
	return result
}

func RbFromBytes(in []byte) (Resp, []byte) {
	if len(in) == 0 {
		return nil, []byte{}
	} else if in[0] == '$' {
		lenStr, leftover, ok := TakeBytesUntilClrf(in[1:])

		if !ok {
			return nil, []byte{}
		}

		len64, err := strconv.ParseInt(string(lenStr), 10, 32)

		if err != nil {
			return nil, []byte{}
		}

		len32 := int(len64)

		// If its negative, regardless what value it is, we just return nil bulk
		if len32 < 0 {
			return &RespNilBulk{}, leftover
		} else {
			// Since we already have the length of the string that we expected, we don't have to use TakeBytesUntilClrf.
			// Instead, we can simply check at the specified index.
			if len32+1 < len(leftover) && leftover[len32] == '\r' && leftover[len32+1] == '\n' {
				rs := RespBulkString{
					inner: string(leftover[:len64]),
				}

				return &rs, leftover[len64+2:]
			} else {
				return nil, []byte{}
			}
		}
	} else {
		return nil, []byte{}
	}
}
```

### Nil Bulk

```golang
// resp.go
type RespNilBulk struct {
}

func (rs *RespNilBulk) AsBytes() []byte {
	return []byte("$-1\r\n")
}
```

### Array

```golang
// resp.go
type RespArray struct {
	inner []Resp
}

func (rs *RespArray) AsBytes() []byte {
	blen := fmt.Sprintf("%d", len(rs.inner))
	result := make([]byte, 0, 1+len(blen)+2)
	result = append(result, []byte("*")...)
	result = append(result, []byte(blen)...)
	result = append(result, []byte("\r\n")...)

	for _, r := range rs.inner {
		b := r.AsBytes()
		result = append(result, b...)
	}

	return result
}

func RaFromBytes(in []byte) (Resp, []byte) {
	if len(in) == 0 {
		return nil, []byte{}
	} else if in[0] == '*' {
		lenStr, leftover, ok := TakeBytesUntilClrf(in[1:])

		if !ok {
			return nil, []byte{}
		}

		len64, err := strconv.ParseInt(string(lenStr), 10, 32)

		if err != nil {
			return nil, []byte{}
		}

		len32 := int(len64)

		// We parsed the length of the array, now we march forward
		nextInput := leftover

		if len32 < 0 {
			return &RespNilArray{}, in
		} else {
			replies := make([]Resp, 0, len32)
			for idx := 0; idx < len32 && len(nextInput) != 0; idx++ {
				reply, leftover := TryConvertBytesToResp(nextInput)

				// If any of the elements are bad or we can't make progress, just bail
				if reply == nil {
					return nil, []byte{}
				}

				nextInput = leftover
				replies = append(replies, reply)
			}

			if len(replies) != len32 {
				return nil, []byte{}
			}

			rs := RespArray{
				inner: replies,
			}

			return &rs, nextInput
		}
	} else {
		return nil, []byte{}
	}
}
```

### Nil Array

```golang
// resp.go
type RespNilArray struct {
}

func (rs *RespNilArray) AsBytes() []byte {
	return []byte("*-1\r\n")
}
```

## Converting From Bytes to RESP

Putting together all the structs and functions we wrote above, we can implement a function that converts bytes to RESP objects,

```golang
// resp.go
func TryConvertBytesToResp(input []byte) (Resp, []byte) {
	// We need at least 1 byte for the first redis type byte
	if len(input) == 0 {
		return nil, []byte{}
	} else if input[0] == '+' { // Simple strings
		resp, leftover := RssFromBytes(input)

		if resp == nil {
			return nil, []byte{}
		}

		return resp, leftover
	} else if input[0] == '-' { // Error strings
		resp, leftover := ResFromBytes(input)

		if resp == nil {
			return nil, []byte{}
		}

		return resp, leftover
	} else if input[0] == ':' { // Integers
		resp, leftover := RiFromBytes(input)

		if resp == nil {
			return nil, []byte{}
		}

		return resp, leftover
	} else if input[0] == '$' { // Bulk strings
		resp, leftover := RbFromBytes(input)

		if resp == nil {
			return nil, []byte{}
		}

		return resp, leftover
	} else if input[0] == '*' { // Arrays
		resp, leftover := RaFromBytes(input)

		if resp == nil {
			return nil, []byte{}
		}

		return resp, leftover
	} else {
		return nil, []byte{}
	}
}
```

And that should be all there is to our RESP library.
The next thing to do is to implement the server and client.

# Implementing redis Client

`redis` already comes with their own standard tool to communicate with it: `redis-cli`.
However, for our use cases (and for fun) we will be implementing our own.
One problem with `redis-cli` is that you cannot test what happens if you send a bad request to redis.
`redis-cli` will automatically sanitize the input for you, which is not what we want for learning purposes.

What we want to do is to manually send a command and then receive a response:

```
$ redis-client "*1$4\r\nPING\r\n"
+PONG
```

Therefore, our `redis-client` is a simple Golang program that:

1. Connects to a port
2. Writes some bytes to that port
3. Read some bytes from that port

Here is the full program plus their explanations,

```golang
// cmd/client/client.go
package main

import (
	"fmt"
	"net"
	"os"
	"strings"

	redis "redis_clone"
)

func main() {
	// Check if user passed in an argument
	if len(os.Args) != 2 {
		fmt.Println("This program only accepts 1 argument which is the data to send to port 6379")
		os.Exit(1)
	}

	// Since we will be dealing with bytes, immediately cast the string to []byte
	data := []byte(ConvertCrlf(os.Args[1]))

	// redis server usually uses port 6379 so we will use that too here
	tcpAddr, err := net.ResolveTCPAddr("tcp", "localhost:6379")

	if err != nil {
		fmt.Printf("Failed to resolve TCP address:%s\n", err)
		os.Exit(1)
	}

	tcpConn, err := net.DialTCP("tcp", nil, tcpAddr)

	if err != nil {
		fmt.Printf("Failed to dial TCP:%s\n", err)
		os.Exit(1)
	}

	defer tcpConn.Close()

	WriteData(tcpConn, data)
	resp := ReadData(tcpConn)
	respBytes := resp.AsBytes()
	fmt.Printf("%v\n", EscapeString(string(respBytes)))
}

// WriteData writes data into the tcp connection
func WriteData(tcpConn *net.TCPConn, data []byte) {
	writtenC := 0

	// tcpConn.Write returns the number of bytes that it have written.
	// Therefore, we need to loop and keep trying to write until we have written all the bytes in data.
	// tcpConn.Write only partially writes the data if the buffer on the tcp connection is smaller than our data
	// or if its busy.
	for {
		c, err := tcpConn.Write(data[writtenC:])

		// Connection might be closed while we are writing?
		// In any case, nothing we can do so just abort.
		if err != nil {
			fmt.Printf("Failed to write to connection%s\n", err)
			os.Exit(1)
		}

		writtenC += c

		// We have finally written all the bytes, break from this loop
		if writtenC == len(data) {
			break
		}
	}
}

// WriteData reads data from the tcp connection
func ReadData(tcpConn *net.TCPConn) redis.Resp {
	total := make([]byte, 0)

	// Similar to tcpConn.Write, reading from a tcp connection might not be complete.
	// So we need to keep trying until the bytes that we received can form a complete RESP object.
	for {
		// A buffer of 1024 length means that we will at most 1024 bytes from the connection.
		// This means that if the server is trying to send something bigger than 1024 bytes, we will have to try multiple times.
		// Try changing it to 0 and see what happen (your application will hang).
		buffer := make([]byte, 1024)
		count, err := tcpConn.Read(buffer)

		// If something bad happens, just abort
		if err != nil {
			fmt.Println("Unable to read from connection")
			os.Exit(1)
		}

		total = append(total, buffer[:count]...)

		// Here, we try to parse the bytes we have and see if it can form a RESP
		resp, _ := redis.TryConvertBytesToResp(total)

		// It does! so return from this function with the resp that we got
		if resp != nil {
			return resp
		}
	}
}

// ConvertClrf converts the textual input of \r (which is 2 seperate UTF-8 character) into the actual '\r'
func ConvertCrlf(in string) string {
	in = strings.ReplaceAll(in, "\\r", "\r")
	in = strings.ReplaceAll(in, "\\n", "\n")
	return in
}

// EscapeString does the reverse of ConvertClrf, since printing them as is will cause the output to have a weird format.
func EscapeString(in string) string {
	in = strings.ReplaceAll(in, "\r", "\\r")
	in = strings.ReplaceAll(in, "\n", "\\n")
	return in
}
```

# Implementing redis Server

Before we implement the actual redis server, we can implement a redis echo server that simply returns back whatever RESP input that it's given.
To show that this is a valid redis server, we will try to send data to it using our client and through `redis-cli`.

The implementation is the following,

```golang
// cmd/echo/echo.go
package main

import (
	"fmt"
	"net"
	"os"
	"time"

	redis "redis_clone"
)

func main() {
	// We want to listen to port 6379
	listen, err := net.Listen("tcp", "localhost:6379")

	if err != nil || listen == nil {
		fmt.Printf("Unable to listen to socket:%s\n", err)
		os.Exit(1)
	}

	// 	Loop forever listening for any connections
	for {
		conn, err := listen.Accept()

		if err != nil {
			fmt.Printf("Unable to accept connection:%s\n", err)
			continue
		}

		// Once we get a connection, we start handling it
		conn.SetDeadline(time.Now().Add(1 * time.Second))
		HandleRequest(conn)
		conn.Close()
	}
}

func HandleRequest(conn net.Conn) {
	total := make([]byte, 0)

	for {
		buffer := make([]byte, 1024)
		count, err := conn.Read(buffer)

		if err != nil {
			fmt.Println("Unable to read from socket")
			return
		}

		total = append(total, buffer[:count]...)
		resp, leftover := redis.TryConvertBytesToResp(total)

		if resp != nil {
			total = leftover
			// For now we just reply back the exact same thing
			WriteData(conn, resp.AsBytes())
		}

		if len(leftover) == 0 {
			return
		}
	}
}

func WriteData(conn net.Conn, data []byte) {
	writeC := 0
	for writeC != len(data) {
		read, err := conn.Write(data[writeC:])

		if err != nil {
			fmt.Println("Unable to write to socket")
			return
		}

		writeC += read
	}
}
```

Now let's try our server and client.
In another shell, run `go run cmd/echo/echo.go`.
Then we can test our redis client by sending valid RESP messages,

```shell
$ go run cmd/client/client.go "+PING\r\n"
+PING\r\n
$ go run cmd/client/client.go "*2\r\n+PING\r\n-PING\r\n"
*2\r\n+PING\r\n-PING\r\n
$ go run cmd/client/client.go "-PING\r\n"
-PING\r\n
```

We can also use the official `redis-cli` and see that it seems to work!

```shell
$ redis-cli -p 6379 set key value
1) "set"
2) "key"
3) "value"
$ redis-cli -p 6379 get key
1) "get"
2) "key"
```

The reason why we get the output in this form is due to how redis commands work.
Basically, most redis command is sent through a RESP array.
So when we type,

`redis-cli -p 6379 set key value`

We are actually sending something like,

`*3\r\n$3\r\nset\r\n$3\r\nkey\r\n$5\r\nvalue\r\n`

And then, since our current redis server is just echoing back whatever it receives, and this is just how `redis-cli` displays RESP arrays!

Now what happens if we send invalid RESP objects?

```shell
$ go run cmd/client/client.go "!PING\r\n"
Unable to read from connection
exit status 1
$ go run cmd/client/client.go "*2\r\n+PING\r\n"
Unable to read from connection
exit status 1
```

We can see that our redis server rejects them outright!
Let's try a basic PING command,

```shell
$ go run cmd/client/client.go "*1\r\n\$4\r\nPING\r\n"
+PONG\r\n
```

What about a basic [SET](https://redis.io/commands/set/) command like `SET KEY VALUE`?

```shell
$ go run cmd/client/client.go "*3\r\n\$3\r\nSET\r\n\$3\r\nKEY\r\n\$5\r\nVALUE\r\n"
+OK\r\n
```

We received the OK from the redis server.
And getting them back using [GET](https://redis.io/commands/get/) command like `GET KEY`?

```shell
$ go run cmd/client/client.go "*2\r\n\$3\r\nGET\r\n\$3\r\nKEY\r\n"
$5\r\nVALUE\r\n
```

And we got our value back!

# Implementing GET and SET commands

Now that our server and client can correctly send and receive RESP objects, we now want it to actually do something with it.
The 2 most basic `redis` command is perhaps the [`GET`](https://redis.io/commands/get/) and [`SET`](https://redis.io/commands/set/) commands.
Using these 2, a client can store data at some key and retrieve them again over the network,

```shell
$ redis-cli -p 6379 set key value
OK
$ redis-cli -p 6379 get key
"value"
```

So we want our `redis` server to contain some kind of state.
Let's implement one is basically just a dictionary underneath,

```golang
// cmd/server/server.go

package main

import (
	"fmt"
	"net"
	"os"
	"strings"
	"time"

	redis "redis_clone"
)

func main() {
	// We want to listen to port 6379
	listen, err := net.Listen("tcp", "localhost:6379")

	if err != nil || listen == nil {
		fmt.Printf("Unable to listen to socket:%s\n", err)
		os.Exit(1)
	}

	state := &State{
		kv: make(map[string]redis.Resp, 0),
	}

	// 	Loop forever listening for any connections
	for {
		conn, err := listen.Accept()

		if err != nil {
			fmt.Printf("Unable to accept connection:%s\n", err)
			continue
		}

		// Once we get a connection, we start handling it
		conn.SetDeadline(time.Now().Add(1 * time.Second))
		HandleRequest(conn, state)
		conn.Close()
	}
}

func HandleRequest(conn net.Conn, state *State) {
	total := make([]byte, 0)

	for {
		buffer := make([]byte, 1024)
		count, err := conn.Read(buffer)

		if err != nil {
			fmt.Println("Unable to read from socket")
			return
		}

		total = append(total, buffer[:count]...)
		resp, leftover := redis.TryConvertBytesToResp(total)

		if resp != nil {
			total = leftover
			// HandleRequest(conn)
			resl := state.HandleResp(resp)
			WriteData(conn, resl.AsBytes())
		}

		if len(leftover) == 0 {
			return
		}
	}
}

func WriteData(conn net.Conn, data []byte) {
	writeC := 0
	for writeC != len(data) {
		read, err := conn.Write(data[writeC:])

		if err != nil {
			fmt.Println("Unable to write to socket")
			return
		}

		writeC += read
	}
}

type State struct {
	// Dictionary of map to RESP
	kv map[string]redis.Resp
}

// Get returns the RESP at key if it exists, otherwise returns nil
func (s *State) Get(key string) redis.Resp {
	v, e := s.kv[key]
	if !e {
		return nil
	} else {
		return v
	}
}

// Set simply maps key to some value. Overwrites the old value
func (s *State) Set(key string, value redis.Resp) {
	s.kv[key] = value
}

// HandleResp takes the RESP, processes it and returns RESP response
func (s *State) HandleResp(resp redis.Resp) redis.Resp {
	// The default error. redis have various kind of error messages
	errResult := &redis.RespErrorString{
		Inner: "please provide a valid redis command",
	}

	rarr := make([]redis.Resp, 0)

	// Make sure that the RESP we received is a RESP array
	if arr, ok := resp.(*redis.RespArray); ok {
		rarr = arr.Inner
	}

	// If its empty, return error (or if the above if failed)
	if len(rarr) == 0 {
		return errResult
	}

	sarr := make([]*redis.RespBulkString, 0, len(rarr))

	// Each RESP in the array must be a bulk string
	for _, r := range rarr {
		if r, ok := r.(*redis.RespBulkString); ok {
			sarr = append(sarr, r)
		} else {
			return errResult
		}
	}

	if strings.ToLower(sarr[0].Inner) == "get" { // GET command
		if len(sarr) != 2 { // GET command requires exactly 2 arguments i.e GET <key>
			return errResult
		} else {
			v := s.Get(sarr[1].Inner)

			if v == nil {
				return &redis.RespNilArray{}
			} else {
				return v
			}
		}
	} else if strings.ToLower(sarr[0].Inner) == "set" { // SET command
		if len(sarr) != 3 { // SET command requires exactly 2 arguments i.e SET <key> <value>
			return errResult
		} else {
			s.Set(sarr[1].Inner, sarr[2])
			return &redis.RespSimpleString{Inner: "OK"}
		}
	} else { // Reject every other commands
		return &redis.RespErrorString{Inner: fmt.Sprintf("command %s is not yet supported", sarr[0].Inner)}
	}
}
```

Now let's try using our `redis` server and client, and see if it works!
Start the server and execute,

```shell
$ go run cmd/client/client.go "*3\r\n\$3\r\nSET\r\n\$3\r\nKEY\r\n\$5\r\nhello\r\n"
+OK\r\n
$ go run cmd/client/client.go "*2\r\n\$3\r\nGET\r\n\$3\r\nKEY\r\n"
$5\r\nhello\r\n
```

Awesome!
You've now implement a basic `redis` clone!
Well...now what?
Here's how you can make this implementation better:

1. Implement all the commands [here](https://redis.io/commands/)....
   Now that's a lot of commands.
   But this should give you a foundation to implement many of them (try to implement `LPUSH`, `LPOP`).
2. You can also try to make this multithreaded using a `RWLock`!
3. Support blocking commands?
4. Persistency by writing to disk?
