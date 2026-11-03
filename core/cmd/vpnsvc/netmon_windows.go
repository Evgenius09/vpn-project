//go:build windows

package main

import (
	"fmt"
	"log/slog"
	"sync"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"

	"github.com/Evgenius09/vpn-project/core/internal/autoswitch"
)

// The connectivity hint API arrived in Windows 10 2004 and is missing from
// x/sys (tech.md 5.7).
var (
	modIphlpapi                                = windows.NewLazySystemDLL("iphlpapi.dll")
	procNotifyNetworkConnectivityHintChange    = modIphlpapi.NewProc("NotifyNetworkConnectivityHintChange")
	procGetNetworkConnectivityHintForInterface = modIphlpapi.NewProc("GetNetworkConnectivityHintForInterface")
)

// connectivityHint is NL_NETWORK_CONNECTIVITY_HINT.
type connectivityHint struct {
	Level                connectivityLevel
	Cost                 connectivityCost
	ApproachingDataLimit uint8
	OverDataLimit        uint8
	Roaming              uint8
}

// The callbacks only wake the watchers: Windows runs them on its own threads,
// and CancelMibChangeNotify2 waits for them, so they must not block. Callbacks
// made by NewCallback are never freed, so there is one of each per process.
var (
	wakeMu   sync.Mutex
	wakeSet  = map[chan struct{}]struct{}{}
	wakeOnce sync.Once
	// The hint callback gets the hint by value, which x64 passes by pointer.
	hintCallback      uintptr
	interfaceCallback uintptr
	routeCallback     uintptr
)

func wakeWatchers() {
	wakeMu.Lock()
	defer wakeMu.Unlock()
	for wake := range wakeSet {
		select {
		case wake <- struct{}{}:
		default:
		}
	}
}

func makeCallbacks() {
	hintCallback = windows.NewCallback(func(_, _ uintptr) uintptr {
		wakeWatchers()
		return 0
	})
	interfaceCallback = windows.NewCallback(func(_, _, _ uintptr) uintptr {
		wakeWatchers()
		return 0
	})
	routeCallback = windows.NewCallback(func(_, _, _ uintptr) uintptr {
		wakeWatchers()
		return 0
	})
}

// watchNetwork returns hostOptions.WatchNetwork. It subscribes to the
// connectivity hint as tech.md 5.7 says, and to interface and route changes,
// because the hint follows the default route, which the tunnel holds while it
// runs.
func watchNetwork(logger *slog.Logger) func(observe func(autoswitch.NetType)) (func(), error) {
	return func(observe func(autoswitch.NetType)) (func(), error) {
		wakeOnce.Do(makeCallbacks)
		wake := make(chan struct{}, 1)
		wakeMu.Lock()
		wakeSet[wake] = struct{}{}
		wakeMu.Unlock()

		handles, err := subscribe(logger)
		if err != nil {
			unsubscribe(handles, wake, logger)
			return nil, err
		}

		detect := func() {
			net, err := detectNetwork()
			if err != nil {
				logger.Warn("detect network", "error", err)
				return
			}
			observe(net)
		}
		detect()

		done := make(chan struct{})
		var loop sync.WaitGroup
		loop.Go(func() {
			for {
				select {
				case <-done:
					return
				case <-wake:
					detect()
				}
			}
		})
		return func() {
			unsubscribe(handles, wake, logger)
			close(done)
			loop.Wait()
		}, nil
	}
}

func subscribe(logger *slog.Logger) ([]windows.Handle, error) {
	var handles []windows.Handle
	var routes, interfaces windows.Handle
	if err := windows.NotifyRouteChange2(windows.AF_UNSPEC, routeCallback, nil, false, &routes); err != nil {
		return handles, fmt.Errorf("subscribe to route changes: %w", err)
	}
	handles = append(handles, routes)
	if err := windows.NotifyIpInterfaceChange(windows.AF_UNSPEC, interfaceCallback, nil, false, &interfaces); err != nil {
		return handles, fmt.Errorf("subscribe to interface changes: %w", err)
	}
	handles = append(handles, interfaces)
	// Without the hint a cost change on the same network goes unnoticed, but
	// route and interface changes still drive the detection.
	hint, err := notifyHintChange()
	if err != nil {
		logger.Warn("subscribe to connectivity hints", "error", err)
		return handles, nil
	}
	return append(handles, hint), nil
}

func notifyHintChange() (windows.Handle, error) {
	if err := procNotifyNetworkConnectivityHintChange.Find(); err != nil {
		return 0, fmt.Errorf("find NotifyNetworkConnectivityHintChange: %w", err)
	}
	var handle windows.Handle
	r0, _, _ := syscall.SyscallN(procNotifyNetworkConnectivityHintChange.Addr(),
		hintCallback, 0, 0, uintptr(unsafe.Pointer(&handle)))
	if r0 != 0 {
		return 0, fmt.Errorf("NotifyNetworkConnectivityHintChange: %w", syscall.Errno(r0))
	}
	return handle, nil
}

func unsubscribe(handles []windows.Handle, wake chan struct{}, logger *slog.Logger) {
	for _, handle := range handles {
		if err := windows.CancelMibChangeNotify2(handle); err != nil {
			logger.Warn("cancel network notification", "error", err)
		}
	}
	wakeMu.Lock()
	delete(wakeSet, wake)
	wakeMu.Unlock()
}

func detectNetwork() (autoswitch.NetType, error) {
	ifaces, err := listInterfaces()
	if err != nil {
		return "", err
	}
	return activeNetwork(ifaces), nil
}

// listInterfaces returns every interface that holds a default route, with the
// lowest metric among its default routes of both families.
func listInterfaces() ([]netInterface, error) {
	var table *windows.MibIpForwardTable2
	if err := windows.GetIpForwardTable2(windows.AF_UNSPEC, &table); err != nil {
		return nil, fmt.Errorf("read routes: %w", err)
	}
	defer windows.FreeMibTable(unsafe.Pointer(table))

	byLUID := map[uint64]*netInterface{}
	var order []uint64
	for _, route := range table.Rows() {
		if route.DestinationPrefix.PrefixLength != 0 {
			continue
		}
		// An interface can vanish between the route table and these reads.
		ipInterface := windows.MibIpInterfaceRow{
			Family: route.DestinationPrefix.Prefix.Family, InterfaceLuid: route.InterfaceLuid,
		}
		if err := windows.GetIpInterfaceEntry(&ipInterface); err != nil {
			continue
		}
		metric := route.Metric + ipInterface.Metric
		if iface, ok := byLUID[route.InterfaceLuid]; ok {
			iface.Metric = min(iface.Metric, metric)
			continue
		}
		row := windows.MibIfRow2{InterfaceLuid: route.InterfaceLuid}
		if err := windows.GetIfEntry2Ex(windows.MibIfTableNormalWithoutStatistics, &row); err != nil {
			continue
		}
		hint := interfaceHint(row.InterfaceIndex)
		byLUID[route.InterfaceLuid] = &netInterface{
			Index:           row.InterfaceIndex,
			Type:            row.Type,
			Medium:          row.PhysicalMediumType,
			Alias:           windows.UTF16ToString(row.Alias[:]),
			Description:     windows.UTF16ToString(row.Description[:]),
			Up:              row.OperStatus == windows.IfOperStatusUp,
			HasDefaultRoute: true,
			Metric:          metric,
			Level:           hint.Level,
			Cost:            hint.Cost,
			Roaming:         hint.Roaming != 0,
		}
		order = append(order, route.InterfaceLuid)
	}

	ifaces := make([]netInterface, 0, len(order))
	for _, luid := range order {
		ifaces = append(ifaces, *byLUID[luid])
	}
	return ifaces, nil
}

// interfaceHint returns a zero hint, unknown level and cost, when Windows has
// none for the interface or lacks the API.
func interfaceHint(index uint32) connectivityHint {
	var hint connectivityHint
	if err := getInterfaceHint(index, &hint); err != nil {
		return connectivityHint{}
	}
	return hint
}

func getInterfaceHint(index uint32, hint *connectivityHint) error {
	if err := procGetNetworkConnectivityHintForInterface.Find(); err != nil {
		return fmt.Errorf("find GetNetworkConnectivityHintForInterface: %w", err)
	}
	r0, _, _ := syscall.SyscallN(procGetNetworkConnectivityHintForInterface.Addr(),
		uintptr(index), uintptr(unsafe.Pointer(hint)))
	if r0 != 0 {
		return fmt.Errorf("GetNetworkConnectivityHintForInterface: %w", syscall.Errno(r0))
	}
	return nil
}
