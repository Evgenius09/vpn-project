// Package ipc implements the vpnsvc protocol, IPC v1 (tech.md 5.6), over any
// io.ReadWriteCloser so that it stays testable off Windows.
package ipc

import (
	"encoding/json"

	"github.com/Evgenius09/vpn-project/core/internal/contract"
)

const (
	// ProtocolVersion is the value both sides exchange in hello.
	ProtocolVersion = 1
	// MaxMessageBytes limits one newline-delimited JSON-RPC message.
	MaxMessageBytes = 4 << 20
	// JSONRPCVersion is the only accepted jsonrpc field value.
	JSONRPCVersion = "2.0"
	// CodeCoreError marks an error whose data carries a CoreErrorCode.
	CodeCoreError = -32000
	// CodeMethodNotFound is the JSON-RPC code for an unknown method.
	CodeMethodNotFound = -32601
	// MethodEvent is the notification that carries a CoreEvent.
	MethodEvent = "event"
)

// Request methods.
const (
	MethodHello         = "hello"
	MethodPrepare       = "prepare"
	MethodStart         = "start"
	MethodUpdate        = "update"
	MethodStop          = "stop"
	MethodSetUserMode   = "setUserMode"
	MethodSelectServer  = "selectServer"
	MethodURLTest       = "urlTest"
	MethodGetState      = "getState"
	MethodSyncRuleSets  = "syncRuleSets"
	MethodListProcesses = "listProcesses"
	MethodSubscribe     = "subscribe"
)

// Methods lists every request method. The first call on a connection must be
// MethodHello.
var Methods = []string{
	MethodHello,
	MethodPrepare,
	MethodStart,
	MethodUpdate,
	MethodStop,
	MethodSetUserMode,
	MethodSelectServer,
	MethodURLTest,
	MethodGetState,
	MethodSyncRuleSets,
	MethodListProcesses,
	MethodSubscribe,
}

// Message is one JSON-RPC 2.0 frame: a request, response, or notification.
type Message struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      *int64          `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *Error          `json:"error,omitempty"`
}

// Error is a JSON-RPC error object.
type Error struct {
	Code    int        `json:"code"`
	Message string     `json:"message"`
	Data    *ErrorData `json:"data,omitempty"`
}

// ErrorData carries the core error code of a CodeCoreError.
type ErrorData struct {
	Code contract.CoreErrorCode `json:"code"`
}

// HelloParams opens a connection.
type HelloParams struct {
	ProtocolVersion int    `json:"protocolVersion"`
	AppVersion      string `json:"appVersion"`
}

// HelloResult reports the service side of the handshake.
type HelloResult struct {
	ProtocolVersion int    `json:"protocolVersion"`
	ServiceVersion  string `json:"serviceVersion"`
}

// PrepareResult is always granted when the service answers.
type PrepareResult struct {
	Result string `json:"result"`
}

// TunnelParams is the payload of start and update.
type TunnelParams struct {
	TunnelRequest contract.TunnelRequest `json:"tunnelRequest"`
}

// SetUserModeParams changes the user mode.
type SetUserModeParams struct {
	Mode contract.TunnelMode `json:"mode"`
}

// SelectServerParams selects a server inside a group.
type SelectServerParams struct {
	Group    contract.TunnelMode `json:"group"`
	ServerID string              `json:"serverId"`
}

// URLTestParams lists the servers to test.
type URLTestParams struct {
	ServerIDs []string `json:"serverIds"`
}

// SyncRuleSetsParams lists the rule sets the service must download.
type SyncRuleSetsParams struct {
	RuleSets []contract.RuleSetRef `json:"ruleSets"`
}

// SyncRuleSetsResult lists the identifiers of ready rule sets.
type SyncRuleSetsResult struct {
	Ready []string `json:"ready"`
}

// ProcessInfo describes one running process.
type ProcessInfo struct {
	Name string `json:"name"`
	Path string `json:"path"`
}
