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
