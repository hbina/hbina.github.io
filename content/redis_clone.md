---
title: "Building a Redis Clone from Scratch in Go"
date: 2022-12-22
author: "Hanif Bin Ariffin"
---

# Building a Redis Clone from Scratch in Go

Have you ever wondered what makes Redis tick? This tutorial will guide you through building your own Redis-compatible server from the ground up. By the end, you'll understand not just Redis, but the fundamental principles behind any networked database.

## What You'll Learn

Redis is more than just a cache—it's one of the world's most popular in-memory data stores, powering everything from session storage to real-time analytics. While the full Redis implementation is incredibly complex, the core concepts are surprisingly accessible.

In this tutorial, you'll build:
- A working Redis server that handles GET and SET commands
- A custom client for testing your server
- A complete implementation of the RESP protocol
- The foundation for any networked application

**Prerequisites**: Basic Go knowledge and familiarity with TCP/IP concepts.

The complete source code is available at [github.com/hbina/redis_clone](https://github.com/hbina/redis_clone).

---

## Understanding RESP: Redis's Communication Protocol

Before writing any code, we need to understand how Redis clients and servers communicate. Redis uses RESP (REdis Serialization Protocol)—a simple, human-readable protocol that's easy to implement and debug.

Think of RESP as a structured way to send messages over a network. Every message has a specific format that both client and server understand.

### The Building Blocks of RESP

RESP has exactly five data types, each identified by its first character:

| Type | Symbol | Example | Use Case |
|------|---------|---------|----------|
| **Simple String** | `+` | `+OK\r\n` | Short responses like "OK" or "PONG" |
| **Error String** | `-` | `-ERR unknown command\r\n` | Error messages |
| **Integer** | `:` | `:42\r\n` | Numbers and counters |
| **Bulk String** | `$` | `$5\r\nhello\r\n` | Any string data, including binary |
| **Array** | `*` | `*2\r\n+PING\r\n+PONG\r\n` | Lists of other RESP types |

All RESP messages end with `\r\n` (carriage return + line feed), which we'll call CRLF.

### Simple Strings: The Basics

Simple strings are perfect for short, predictable responses:

```
+OK\r\n
+PONG\r\n
+Hello World\r\n
```

The format is straightforward:
1. `+` indicates a simple string
2. Your content follows immediately  
3. `\r\n` terminates the message

**Important limitation**: Simple strings cannot contain `\r\n` in their content. If your data might include newlines, use bulk strings instead.

### Error Strings: Communicating Problems

Error strings work identically to simple strings but use `-` to indicate an error condition:

```
-ERR unknown command 'foobar'\r\n
-WRONGTYPE Operation against a key holding the wrong kind of value\r\n
```

This distinction allows clients to handle errors appropriately without parsing the content.

### Integers: Numbers Made Simple

Integers represent decimal numbers:

```
:42\r\n
:-17\r\n
:1000\r\n
```

Note: Only decimal format is supported—no hexadecimal or scientific notation.

### Bulk Strings: The Workhorse

Bulk strings are more complex but handle any content, including binary data:

```
$4\r\nPING\r\n
$11\r\nHello World\r\n
$13\r\nHello\r\nWorld\r\n
```

The format includes a length prefix:
1. `$` indicates a bulk string
2. Length in bytes (decimal)
3. `\r\n` separator
4. Exactly that many bytes of content
5. Final `\r\n`

**Why use bulk strings?** Two key advantages:
- **Safety**: Can contain `\r\n` safely since we know the exact length
- **Performance**: No need to scan for terminators in large data

### Arrays: Combining Everything

Arrays contain multiple RESP elements:

```
*2\r\n+PING\r\n+PONG\r\n
```

This represents an array with two simple strings: "PING" and "PONG".

Arrays can be nested. Here's how `[["hello", "world"], ["foo", "bar"]]` looks in RESP:

```
*2\r\n*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n
```

Breaking it down:
- `*2\r\n` - Array of 2 elements
- `*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n` - First sub-array: ["hello", "world"]  
- `*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n` - Second sub-array: ["foo", "bar"]

### Null Values

RESP represents null values using negative lengths:
- Null bulk string: `$-1\r\n`
- Null array: `*-1\r\n`

This elegant solution avoids the need for special error handling when data doesn't exist.

---

## Implementing RESP in Go

Now let's build our RESP parser. We'll start with a helper function since many RESP types need to find the CRLF terminator.

### CRLF Helper Function

```go
// resp.go
func TakeBytesUntilCRLF(in []byte) (content []byte, remaining []byte, found bool) {
    if len(in) == 0 {
        return nil, nil, false
    }

    for i := 0; i < len(in)-1; i++ {
        if in[i] == '\r' && in[i+1] == '\n' {
            return in[:i], in[i+2:], true
        }
    }
    
    return in, nil, false
}
```

This function searches for `\r\n` and returns the content before it, any remaining bytes, and whether we found a complete message.

### The RESP Interface

We'll define a common interface for all RESP types:

```go
type Resp interface {
    AsBytes() []byte
}
```

This lets us convert any RESP object back to its wire format for network transmission.

### Simple String Implementation

```go
type RespSimpleString struct {
    Value string
}

func (r *RespSimpleString) AsBytes() []byte {
    return []byte("+" + r.Value + "\r\n")
}

func ParseSimpleString(data []byte) (*RespSimpleString, []byte, error) {
    if len(data) == 0 || data[0] != '+' {
        return nil, data, errors.New("not a simple string")
    }
    
    content, remaining, found := TakeBytesUntilCRLF(data[1:])
    if !found {
        return nil, data, errors.New("incomplete simple string")
    }
    
    return &RespSimpleString{Value: string(content)}, remaining, nil
}
```

### Error String Implementation

Error strings are nearly identical to simple strings:

```go
type RespError struct {
    Message string
}

func (r *RespError) AsBytes() []byte {
    return []byte("-" + r.Message + "\r\n")
}

func ParseError(data []byte) (*RespError, []byte, error) {
    if len(data) == 0 || data[0] != '-' {
        return nil, data, errors.New("not an error string")
    }
    
    content, remaining, found := TakeBytesUntilCRLF(data[1:])
    if !found {
        return nil, data, errors.New("incomplete error string")
    }
    
    return &RespError{Message: string(content)}, remaining, nil
}
```

### Integer Implementation

```go
type RespInteger struct {
    Value int64
}

func (r *RespInteger) AsBytes() []byte {
    return []byte(":" + strconv.FormatInt(r.Value, 10) + "\r\n")
}

func ParseInteger(data []byte) (*RespInteger, []byte, error) {
    if len(data) == 0 || data[0] != ':' {
        return nil, data, errors.New("not an integer")
    }
    
    content, remaining, found := TakeBytesUntilCRLF(data[1:])
    if !found {
        return nil, data, errors.New("incomplete integer")
    }
    
    value, err := strconv.ParseInt(string(content), 10, 64)
    if err != nil {
        return nil, data, err
    }
    
    return &RespInteger{Value: value}, remaining, nil
}
```

### Bulk String Implementation

Bulk strings are more complex due to their length-prefixed format:

```go
type RespBulkString struct {
    Value []byte
    IsNull bool
}

func (r *RespBulkString) AsBytes() []byte {
    if r.IsNull {
        return []byte("$-1\r\n")
    }
    
    length := strconv.Itoa(len(r.Value))
    result := "$" + length + "\r\n"
    result += string(r.Value) + "\r\n"
    return []byte(result)
}

func ParseBulkString(data []byte) (*RespBulkString, []byte, error) {
    if len(data) == 0 || data[0] != '$' {
        return nil, data, errors.New("not a bulk string")
    }
    
    lengthStr, remaining, found := TakeBytesUntilCRLF(data[1:])
    if !found {
        return nil, data, errors.New("incomplete bulk string length")
    }
    
    length, err := strconv.Atoi(string(lengthStr))
    if err != nil {
        return nil, data, err
    }
    
    // Handle null bulk string
    if length < 0 {
        return &RespBulkString{IsNull: true}, remaining, nil
    }
    
    // Check if we have enough data
    if len(remaining) < length+2 {
        return nil, data, errors.New("incomplete bulk string data")
    }
    
    content := remaining[:length]
    finalRemaining := remaining[length+2:] // Skip content + \r\n
    
    return &RespBulkString{Value: content}, finalRemaining, nil
}
```

### Array Implementation

Arrays are recursive structures that can contain any RESP type:

```go
type RespArray struct {
    Elements []Resp
    IsNull   bool
}

func (r *RespArray) AsBytes() []byte {
    if r.IsNull {
        return []byte("*-1\r\n")
    }
    
    result := "*" + strconv.Itoa(len(r.Elements)) + "\r\n"
    for _, elem := range r.Elements {
        result += string(elem.AsBytes())
    }
    return []byte(result)
}

func ParseArray(data []byte) (*RespArray, []byte, error) {
    if len(data) == 0 || data[0] != '*' {
        return nil, data, errors.New("not an array")
    }
    
    lengthStr, remaining, found := TakeBytesUntilCRLF(data[1:])
    if !found {
        return nil, data, errors.New("incomplete array length")
    }
    
    length, err := strconv.Atoi(string(lengthStr))
    if err != nil {
        return nil, data, err
    }
    
    // Handle null array
    if length < 0 {
        return &RespArray{IsNull: true}, remaining, nil
    }
    
    elements := make([]Resp, 0, length)
    current := remaining
    
    for i := 0; i < length; i++ {
        elem, newRemaining, err := ParseResp(current)
        if err != nil {
            return nil, data, err
        }
        elements = append(elements, elem)
        current = newRemaining
    }
    
    return &RespArray{Elements: elements}, current, nil
}
```

### Universal RESP Parser

Finally, we need a function that can parse any RESP type:

```go
func ParseResp(data []byte) (Resp, []byte, error) {
    if len(data) == 0 {
        return nil, data, errors.New("empty data")
    }
    
    switch data[0] {
    case '+':
        return ParseSimpleString(data)
    case '-':
        return ParseError(data)
    case ':':
        return ParseInteger(data)
    case '$':
        return ParseBulkString(data)
    case '*':
        return ParseArray(data)
    default:
        return nil, data, errors.New("unknown RESP type")
    }
}
```

---

## Building the Redis Client

Before implementing our server, let's create a simple client to test our RESP implementation. Our client will be more flexible than `redis-cli` for learning purposes—it can send malformed messages to test edge cases.

### Client Goals

Our client should:
1. Connect to Redis on port 6379
2. Send raw RESP messages
3. Display the response in a readable format
4. Handle connection errors gracefully

### Client Implementation

```go
// cmd/client/main.go
package main

import (
    "fmt"
    "net"
    "os"
    "strings"
)

func main() {
    if len(os.Args) != 2 {
        fmt.Println("Usage: client <RESP_MESSAGE>")
        fmt.Println("Example: client \"*1\\r\\n$4\\r\\nPING\\r\\n\"")
        os.Exit(1)
    }

    // Convert escaped characters to actual control characters
    message := unescapeMessage(os.Args[1])
    
    // Connect to Redis server
    conn, err := net.Dial("tcp", "localhost:6379")
    if err != nil {
        fmt.Printf("Failed to connect: %v\n", err)
        os.Exit(1)
    }
    defer conn.Close()

    // Send message
    _, err = conn.Write([]byte(message))
    if err != nil {
        fmt.Printf("Failed to send message: %v\n", err)
        os.Exit(1)
    }

    // Read response
    buffer := make([]byte, 4096)
    n, err := conn.Read(buffer)
    if err != nil {
        fmt.Printf("Failed to read response: %v\n", err)
        os.Exit(1)
    }

    // Display response with escaped control characters for readability
    response := escapeMessage(string(buffer[:n]))
    fmt.Printf("Response: %s\n", response)
}

func unescapeMessage(s string) string {
    s = strings.ReplaceAll(s, "\\r", "\r")
    s = strings.ReplaceAll(s, "\\n", "\n")
    return s
}

func escapeMessage(s string) string {
    s = strings.ReplaceAll(s, "\r", "\\r")
    s = strings.ReplaceAll(s, "\n", "\\n")
    return s
}
```

This client allows us to send raw RESP messages and see exactly what the server responds with.

---

## Building the Redis Server

Now for the main event—our Redis server! We'll start with an echo server to verify our RESP implementation, then add actual Redis commands.

### Echo Server: Testing Our Foundation

An echo server simply returns whatever it receives. This helps us verify that our RESP parsing works correctly:

```go
// cmd/echo/main.go
package main

import (
    "fmt"
    "net"
    "os"
)

func main() {
    listener, err := net.Listen("tcp", ":6379")
    if err != nil {
        fmt.Printf("Failed to listen: %v\n", err)
        os.Exit(1)
    }
    defer listener.Close()

    fmt.Println("Echo server listening on :6379")

    for {
        conn, err := listener.Accept()
        if err != nil {
            fmt.Printf("Failed to accept connection: %v\n", err)
            continue
        }

        go handleConnection(conn)
    }
}

func handleConnection(conn net.Conn) {
    defer conn.Close()
    
    buffer := make([]byte, 4096)
    for {
        n, err := conn.Read(buffer)
        if err != nil {
            return // Connection closed
        }

        data := buffer[:n]
        resp, remaining, err := ParseResp(data)
        if err != nil {
            fmt.Printf("Parse error: %v\n", err)
            return
        }

        // Echo the parsed message back
        _, err = conn.Write(resp.AsBytes())
        if err != nil {
            fmt.Printf("Write error: %v\n", err)
            return
        }

        // Handle any remaining data in the buffer
        if len(remaining) == 0 {
            return
        }
    }
}
```

### Testing the Echo Server

Start the echo server:
```bash
go run cmd/echo/main.go
```

Test with our client:
```bash
go run cmd/client/main.go "*1\r\n$4\r\nPING\r\n"
# Response: *1\r\n$4\r\nPING\r\n
```

The server successfully parsed our RESP array and echoed it back!

### Full Redis Server Implementation

Now let's build a real Redis server that handles GET and SET commands:

```go
// cmd/server/main.go
package main

import (
    "fmt"
    "net"
    "os"
    "strings"
    "sync"
)

type RedisServer struct {
    data map[string][]byte
    mu   sync.RWMutex
}

func NewRedisServer() *RedisServer {
    return &RedisServer{
        data: make(map[string][]byte),
    }
}

func (s *RedisServer) Get(key string) ([]byte, bool) {
    s.mu.RLock()
    defer s.mu.RUnlock()
    
    value, exists := s.data[key]
    return value, exists
}

func (s *RedisServer) Set(key string, value []byte) {
    s.mu.Lock()
    defer s.mu.Unlock()
    
    s.data[key] = value
}

func (s *RedisServer) HandleCommand(cmd *RespArray) Resp {
    if cmd.IsNull || len(cmd.Elements) == 0 {
        return &RespError{Message: "ERR empty command"}
    }

    // Convert command elements to strings
    args := make([]string, len(cmd.Elements))
    for i, elem := range cmd.Elements {
        if bulkStr, ok := elem.(*RespBulkString); ok && !bulkStr.IsNull {
            args[i] = string(bulkStr.Value)
        } else {
            return &RespError{Message: "ERR invalid command format"}
        }
    }

    command := strings.ToUpper(args[0])

    switch command {
    case "PING":
        if len(args) == 1 {
            return &RespSimpleString{Value: "PONG"}
        } else if len(args) == 2 {
            return &RespBulkString{Value: []byte(args[1])}
        } else {
            return &RespError{Message: "ERR wrong number of arguments for 'ping' command"}
        }

    case "GET":
        if len(args) != 2 {
            return &RespError{Message: "ERR wrong number of arguments for 'get' command"}
        }
        
        value, exists := s.Get(args[1])
        if !exists {
            return &RespBulkString{IsNull: true}
        }
        return &RespBulkString{Value: value}

    case "SET":
        if len(args) != 3 {
            return &RespError{Message: "ERR wrong number of arguments for 'set' command"}
        }
        
        s.Set(args[1], []byte(args[2]))
        return &RespSimpleString{Value: "OK"}

    default:
        return &RespError{Message: fmt.Sprintf("ERR unknown command '%s'", command)}
    }
}

func main() {
    server := NewRedisServer()
    
    listener, err := net.Listen("tcp", ":6379")
    if err != nil {
        fmt.Printf("Failed to listen: %v\n", err)
        os.Exit(1)
    }
    defer listener.Close()

    fmt.Println("Redis server listening on :6379")

    for {
        conn, err := listener.Accept()
        if err != nil {
            fmt.Printf("Failed to accept connection: %v\n", err)
            continue
        }

        go server.handleConnection(conn)
    }
}

func (s *RedisServer) handleConnection(conn net.Conn) {
    defer conn.Close()
    
    buffer := make([]byte, 4096)
    accumulated := []byte{}

    for {
        n, err := conn.Read(buffer)
        if err != nil {
            return // Connection closed
        }

        accumulated = append(accumulated, buffer[:n]...)

        for len(accumulated) > 0 {
            resp, remaining, err := ParseResp(accumulated)
            if err != nil {
                // Not enough data yet, wait for more
                break
            }

            // Process the command
            var response Resp
            if cmd, ok := resp.(*RespArray); ok {
                response = s.HandleCommand(cmd)
            } else {
                response = &RespError{Message: "ERR Protocol error"}
            }

            // Send response
            _, err = conn.Write(response.AsBytes())
            if err != nil {
                return
            }

            accumulated = remaining
        }
    }
}
```

### Testing the Full Server

Start the server:
```bash
go run cmd/server/main.go
```

Test basic commands:
```bash
# Test PING
go run cmd/client/main.go "*1\r\n$4\r\nPING\r\n"
# Response: +PONG\r\n

# Test SET
go run cmd/client/main.go "*3\r\n$3\r\nSET\r\n$3\r\nkey\r\n$5\r\nvalue\r\n"
# Response: +OK\r\n

# Test GET
go run cmd/client/main.go "*2\r\n$3\r\nGET\r\n$3\r\nkey\r\n"
# Response: $5\r\nvalue\r\n
```

You can also test with the official `redis-cli`:
```bash
redis-cli -p 6379 SET mykey "Hello, Redis!"
redis-cli -p 6379 GET mykey
```

---

## Wrapping Up

Congratulations! You've built a working Redis server from scratch. Your implementation includes:

- ✅ Complete RESP protocol parser
- ✅ Thread-safe data storage with read/write locks
- ✅ Essential Redis commands (PING, GET, SET)
- ✅ Proper error handling and edge case management
- ✅ Compatibility with standard Redis clients

### What You've Learned

This project taught you:
- **Protocol design**: How simple, well-defined protocols enable complex systems
- **Network programming**: TCP connection handling and message parsing
- **Concurrent programming**: Thread safety in multi-client scenarios
- **System architecture**: Building robust, scalable networked applications

### Next Steps

Ready to take your Redis clone further? Try implementing:

1. **More data types**: Lists (`LPUSH`, `LPOP`), sets (`SADD`, `SMEMBERS`), hashes (`HSET`, `HGET`)
2. **Persistence**: Save data to disk with RDB snapshots or AOF logging
3. **Pub/Sub**: Real-time messaging with `PUBLISH` and `SUBSCRIBE`
4. **Expiration**: Time-based key expiry with `EXPIRE` and `TTL`
5. **Clustering**: Multiple servers working together
6. **Memory optimization**: Efficient data structures and memory management

### Key Takeaways

Building complex systems starts with understanding the fundamentals. Redis's power comes not from magic, but from solid engineering principles:
- Simple, well-defined protocols
- Clear separation of concerns
- Robust error handling
- Performance-conscious design

The patterns you've learned here apply to any networked application, from web servers to distributed databases. Now go build something amazing!

---

**Source Code**: [github.com/hbina/redis_clone](https://github.com/hbina/redis_clone)

**Further Reading**:
- [Redis Protocol Specification](https://redis.io/docs/reference/protocol-spec/)
- [Redis Commands Reference](https://redis.io/commands/)
- [Go Network Programming Guide](https://golang.org/doc/articles/wiki/)