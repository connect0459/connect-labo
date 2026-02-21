package term

import (
	"fmt"
	"os"
)

var enabled = func() bool {
	info, err := os.Stdout.Stat()
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeCharDevice != 0
}()

func wrap(code, s string) string {
	if !enabled {
		return s
	}
	return fmt.Sprintf("\033[%sm%s\033[0m", code, s)
}

func Bold(s string) string      { return wrap("1", s) }
func Dim(s string) string       { return wrap("2", s) }
func Red(s string) string       { return wrap("31", s) }
func Green(s string) string     { return wrap("32", s) }
func Cyan(s string) string      { return wrap("36", s) }
func BoldGreen(s string) string { return wrap("1;32", s) }
