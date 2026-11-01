SHELL := bash
.SHELLFLAGS := -euo pipefail -c

# Tags follow the upstream release build in cmd/internal/build_libbox, without
# the features this client does not use (tech.md 3).
TAGS := with_gvisor,with_quic,with_utls,badlinkname,tfogo_checklinkname0
LDFLAGS := -checklinkname=0 -s -w -buildid=
LIBBOX := github.com/sagernet/sing-box/experimental/libbox
ANDROID_API := 23
# arm64 for devices, amd64 for the emulator. Releases add the 32-bit targets.
ANDROID_TARGET ?= android/arm64,android/amd64

.PHONY: android build check test

android:
	mkdir -p build
	gomobile bind -target $(ANDROID_TARGET) -androidapi $(ANDROID_API) \
		-javapkg=com.vpnclient.core -libname=box -trimpath -buildvcs=false \
		-ldflags "$(LDFLAGS)" -tags $(TAGS) -o build/core.aar ./bind $(LIBBOX)

check:
	test -z "$$(gofmt -l .)" || { echo "gofmt needed in core"; exit 1; }
	go vet -tags $(TAGS) ./...
	golangci-lint run --config ../.golangci.yml --build-tags $(TAGS) ./...

build:
	go build -tags $(TAGS) -ldflags "$(LDFLAGS)" ./...

test:
	go test -tags $(TAGS) -ldflags "$(LDFLAGS)" ./...
