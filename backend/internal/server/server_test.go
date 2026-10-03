package server

import (
	"blackbox/internal/engine"
	"blackbox/internal/protocol"
	"blackbox/internal/storage"
	"context"
	"encoding/json"
	"net"
	"net/http"
	"path/filepath"
	"testing"
	"time"

	"github.com/fasthttp/websocket"
)

func TestWebSocketCommandsAndOrigin(t *testing.T) {
	store, err := storage.Open(filepath.Join(t.TempDir(), "ws.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	ctx, cancel := context.WithCancel(context.Background())
	e, err := engine.New(ctx, store)
	if err != nil {
		t.Fatal(err)
	}
	go e.Run(ctx)
	app := New(e, t.TempDir())
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go app.Listener(listener)
	defer func() { cancel(); e.Wait(); app.ShutdownWithTimeout(time.Second) }()
	url := "ws://" + listener.Addr().String() + "/ws"
	var conn *websocket.Conn
	for i := 0; i < 50; i++ {
		conn, _, err = websocket.DefaultDialer.Dial(url, nil)
		if err == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	conn.SetReadDeadline(time.Now().Add(20 * time.Second))
	_, bytes, err := conn.ReadMessage()
	if err != nil {
		t.Fatal(err)
	}
	var initial protocol.Message
	if err = json.Unmarshal(bytes, &initial); err != nil || initial.Snapshot == nil {
		t.Fatal("missing snapshot", err)
	}
	if err = conn.WriteJSON(protocol.Command{Type: "step", RequestID: "websocket-step", Days: 1}); err != nil {
		t.Fatal(err)
	}
	ack, updated := false, false
	for !ack || !updated {
		_, bytes, err = conn.ReadMessage()
		if err != nil {
			t.Fatal(err)
		}
		var m protocol.Message
		if err = json.Unmarshal(bytes, &m); err != nil {
			t.Fatal(err)
		}
		if m.Type == "ack" && m.RequestID == "websocket-step" {
			ack = true
		}
		if m.Snapshot != nil && m.Snapshot.Day == initial.Snapshot.Day+1 {
			updated = true
		}
	}
	bad, resp, err := websocket.DefaultDialer.Dial(url, http.Header{"Origin": []string{"https://unrelated.example"}})
	if bad != nil {
		bad.Close()
	}
	if err == nil || resp.StatusCode != 403 {
		t.Fatal("cross-origin browser connection accepted")
	}
}
