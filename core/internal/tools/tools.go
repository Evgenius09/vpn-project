//go:build tools

// Package tools pins the gomobile fork that upstream sing-box builds with, so
// gomobile bind finds its support packages in this module.
package tools

import _ "github.com/sagernet/gomobile"
