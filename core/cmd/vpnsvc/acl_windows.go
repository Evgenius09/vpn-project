//go:build windows

package main

import (
	"fmt"

	"golang.org/x/sys/windows"
)

// fileSecurity leaves only SYSTEM and Administrators (tech.md 5.6).
const fileSecurity = "D:P(A;;GA;;;SY)(A;;GA;;;BA)"

func protectFile(path string) error {
	descriptor, err := windows.SecurityDescriptorFromString(fileSecurity)
	if err != nil {
		return fmt.Errorf("parse descriptor: %w", err)
	}
	dacl, _, err := descriptor.DACL()
	if err != nil {
		return fmt.Errorf("read dacl: %w", err)
	}
	// PROTECTED drops what the directory would pass down.
	information := windows.SECURITY_INFORMATION(windows.DACL_SECURITY_INFORMATION | windows.PROTECTED_DACL_SECURITY_INFORMATION)
	if err := windows.SetNamedSecurityInfo(path, windows.SE_FILE_OBJECT, information, nil, nil, dacl, nil); err != nil {
		return fmt.Errorf("set dacl: %w", err)
	}
	return nil
}
