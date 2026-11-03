//go:build windows

package main

import (
	"errors"
	"fmt"
	"unsafe"

	"golang.org/x/sys/windows"

	"github.com/Evgenius09/vpn-project/core/internal/ipc"
)

const maxImagePath = 32 * 1024

func listProcesses() ([]ipc.ProcessInfo, error) {
	snapshot, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return nil, fmt.Errorf("create snapshot: %w", err)
	}
	defer func() { _ = windows.CloseHandle(snapshot) }()

	var processes []ipc.ProcessInfo
	entry := windows.ProcessEntry32{Size: uint32(unsafe.Sizeof(windows.ProcessEntry32{}))}
	for err = windows.Process32First(snapshot, &entry); err == nil; err = windows.Process32Next(snapshot, &entry) {
		processes = append(processes, ipc.ProcessInfo{
			Name: windows.UTF16ToString(entry.ExeFile[:]),
			Path: imagePath(entry.ProcessID),
		})
	}
	if !errors.Is(err, windows.ERROR_NO_MORE_FILES) {
		return nil, fmt.Errorf("walk snapshot: %w", err)
	}
	return processes, nil
}

// imagePath returns "" for a protected process: its name is still useful.
func imagePath(processID uint32) string {
	process, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, processID)
	if err != nil {
		return ""
	}
	defer func() { _ = windows.CloseHandle(process) }()

	buffer := make([]uint16, maxImagePath)
	size := uint32(len(buffer))
	if err := windows.QueryFullProcessImageName(process, 0, &buffer[0], &size); err != nil {
		return ""
	}
	return windows.UTF16ToString(buffer[:size])
}
