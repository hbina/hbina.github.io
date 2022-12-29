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
