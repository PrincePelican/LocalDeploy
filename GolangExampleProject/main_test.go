package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHelloEndpoint(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/hello", nil)
	recorder := httptest.NewRecorder()

	newRouter().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, recorder.Code)
	}

}
