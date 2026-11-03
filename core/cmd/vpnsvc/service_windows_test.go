//go:build windows

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Microsoft/go-winio"
	"github.com/stretchr/testify/require"
	"golang.org/x/sys/windows"
)

func daclOf(t *testing.T, path string) string {
	t.Helper()
	descriptor, err := windows.GetNamedSecurityInfo(path, windows.SE_FILE_OBJECT, windows.DACL_SECURITY_INFORMATION)
	require.NoError(t, err)
	return descriptor.String()
}

// The ACL of tech.md 5.6, read back from the live pipe.
func TestPipeACL(t *testing.T) {
	name := fmt.Sprintf(`\\.\pipe\vpnclient-acl-test-%d`, os.Getpid())
	listener, err := winio.ListenPipe(name, &winio.PipeConfig{SecurityDescriptor: pipeSecurity})
	require.NoError(t, err)
	defer func() { require.NoError(t, listener.Close()) }()

	dacl := daclOf(t, name)
	require.Contains(t, dacl, ";;;SY)", dacl)
	require.Contains(t, dacl, ";;;BA)", dacl)
	require.Contains(t, dacl, ";;;AU)", dacl)
	require.Equal(t, 3, strings.Count(dacl, "(A;"), dacl)
}

func TestLastRequestACL(t *testing.T) {
	path := filepath.Join(t.TempDir(), lastRequestFile)
	require.NoError(t, writeProtected(path, "secret", protectFile))

	dacl := daclOf(t, path)
	require.Contains(t, dacl, ";;;SY)", dacl)
	require.Contains(t, dacl, ";;;BA)", dacl)
	require.Equal(t, 2, strings.Count(dacl, "(A;"), dacl)
	require.NotContains(t, dacl, ";;;AU)", dacl)
	require.NotContains(t, dacl, ";;;BU)", dacl)
}

func TestListProcessesFindsThisTest(t *testing.T) {
	processes, err := listProcesses()
	require.NoError(t, err)

	executable, err := os.Executable()
	require.NoError(t, err)
	found := false
	for _, process := range processes {
		if strings.EqualFold(process.Name, filepath.Base(executable)) {
			found = true
			require.NotEmpty(t, process.Path)
		}
	}
	require.True(t, found)
}
