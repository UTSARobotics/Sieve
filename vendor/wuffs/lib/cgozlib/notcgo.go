// Copyright 2019 The Wuffs Authors.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// https://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or https://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.
//
// SPDX-License-Identifier: Apache-2.0 OR MIT

// ----------------

//go:build !cgo
// +build !cgo

package cgozlib

// This file contains placeholder types and funcs so that the package still
// builds (with the same API) when CGO_ENABLED=0. The package doesn't work
// without cgo, but it will fail at run time, not compile time.
//
// In particular, the build stays green regardless of whether CGO_ENABLED is on
// or off. Installing and testing every package in the whole repository will
// not fail. The tests in this package don't pass, but they are skipped.

import (
	"errors"
	"io"
)

const cgoEnabled = false

var (
	errCgoIsNotEnabled = errors.New("cgozlib: cgo is not enabled")
)

type Reader struct{}

func (r *Reader) Close() error                  { return errCgoIsNotEnabled }
func (r *Reader) Read([]byte) (int, error)      { return 0, errCgoIsNotEnabled }
func (r *Reader) Reset(io.Reader, []byte) error { return errCgoIsNotEnabled }
