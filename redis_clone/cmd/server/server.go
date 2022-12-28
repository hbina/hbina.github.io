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

	// Initialize the state of the server
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
			// Instead of simply writing back the RESP we've received, we process it using HandleResp below.
			// WriteData(conn, resp.AsBytes())
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
