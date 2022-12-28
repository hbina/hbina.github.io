// resp.go

package redis_clone

import (
	"fmt"
	"strconv"
)

type Resp interface {
	// Converts into their byte representation.
	// For example a RESP simple string that contains "hello" will convert into `+hello\r\n`
	AsBytes() []byte

	// Something like:
	// static FromBytes([]byte) Resp
	// would be really useful here but alas, Golang doesn't provide such feature
}

var _ Resp = &RespSimpleString{}
var _ Resp = &RespBulkString{}
var _ Resp = &RespInteger{}
var _ Resp = &RespNilBulk{}
var _ Resp = &RespArray{}

type RespSimpleString struct {
	Inner string
}

func (rs *RespSimpleString) AsBytes() []byte {
	result := make([]byte, 0, 1+len(rs.Inner)+2)
	result = append(result, []byte("+")...)
	result = append(result, []byte(rs.Inner)...)
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
			Inner: string(str),
		}

		return &rs, leftover
	} else {
		return nil, []byte{}
	}
}

type RespErrorString struct {
	Inner string
}

func (rs *RespErrorString) AsBytes() []byte {
	result := make([]byte, 0, 1+len(rs.Inner)+2)
	result = append(result, []byte("-")...)
	result = append(result, []byte(rs.Inner)...)
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
			Inner: string(str),
		}

		return &rs, leftover
	} else {
		return nil, []byte{}
	}
}

type RespInteger struct {
	Inner int
}

func (rs *RespInteger) AsBytes() []byte {
	v := fmt.Sprintf("%d", rs.Inner)
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
			Inner: int(val),
		}

		return &rs, leftover
	} else {
		return nil, []byte{}
	}
}

type RespBulkString struct {
	Inner string
}

func (rs *RespBulkString) AsBytes() []byte {
	a := fmt.Sprintf("%d", len(rs.Inner))
	b := []byte(rs.Inner)
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
					Inner: string(leftover[:len64]),
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

type RespNilBulk struct {
}

func (rs *RespNilBulk) AsBytes() []byte {
	return []byte("$-1\r\n")
}

type RespArray struct {
	Inner []Resp
}

func (rs *RespArray) AsBytes() []byte {
	blen := fmt.Sprintf("%d", len(rs.Inner))
	result := make([]byte, 0, 1+len(blen)+2)
	result = append(result, []byte("*")...)
	result = append(result, []byte(blen)...)
	result = append(result, []byte("\r\n")...)

	for _, r := range rs.Inner {
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
				Inner: replies,
			}

			return &rs, nextInput
		}
	} else {
		return nil, []byte{}
	}
}

type RespNilArray struct {
}

func (rs *RespNilArray) AsBytes() []byte {
	return []byte("*-1\r\n")
}

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
