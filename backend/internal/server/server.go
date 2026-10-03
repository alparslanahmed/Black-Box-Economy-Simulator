package server

import (
	"blackbox/internal/engine"
	"blackbox/internal/protocol"
	"context"
	"encoding/json"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gofiber/contrib/v3/websocket"
	"github.com/gofiber/fiber/v3"
)

func New(e *engine.Engine, webRoot string) *fiber.App {
	app := fiber.New(fiber.Config{AppName: "Black Box", BodyLimit: 64 << 10})
	app.Get("/health", func(c fiber.Ctx) error { return c.JSON(fiber.Map{"status": "ok", "protocol": protocol.Version}) })
	app.Use("/ws", func(c fiber.Ctx) error {
		// This is a local observer application. Block browser requests from
		// unrelated sites; same-host Vite and the production UI are allowed.
		if raw := c.Get("Origin"); raw != "" {
			origin, err := url.Parse(raw)
			if err != nil {
				return fiber.ErrForbidden
			}
			hostURL, hostErr := url.Parse("http://" + c.Get("Host"))
			if hostErr != nil {
				return fiber.ErrForbidden
			}
			host := hostURL.Hostname()
			if origin.Hostname() != host {
				return fiber.ErrForbidden
			}
		}
		if !websocket.IsWebSocketUpgrade(c) {
			return fiber.ErrUpgradeRequired
		}
		return c.Next()
	})
	app.Get("/ws", websocket.New(func(conn *websocket.Conn) {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		defer conn.Close()
		conn.SetReadLimit(64 << 10)
		updates, unsubscribe := e.Subscribe()
		defer unsubscribe()
		replies := make(chan []byte, 16)
		writerDone := make(chan struct{})
		// Exactly one writer per socket; a slow viewer cannot stall the world.
		go func() {
			defer close(writerDone)
			defer cancel()
			defer conn.Close()
			ping := time.NewTicker(20 * time.Second)
			defer ping.Stop()
			for {
				var data []byte
				select {
				case <-ctx.Done():
					return
				case data = <-replies:
				case data = <-updates:
				case <-ping.C:
					if err := conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(5*time.Second)); err != nil {
						return
					}
					continue
				}
				conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
				if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
					return
				}
			}
		}()
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		conn.SetPongHandler(func(string) error { return conn.SetReadDeadline(time.Now().Add(60 * time.Second)) })
		for {
			kind, data, err := conn.ReadMessage()
			if err != nil {
				break
			}
			if kind != websocket.TextMessage {
				continue
			}
			var c protocol.Command
			var response protocol.Message
			if err = json.Unmarshal(data, &c); err != nil {
				response = protocol.Message{Version: protocol.Version, Type: "error", Error: "Invalid command JSON"}
			} else {
				response = e.Submit(ctx, c)
			}
			payload, _ := json.Marshal(response)
			select {
			case replies <- payload:
			case <-ctx.Done():
				cancel()
				<-writerDone
				return
			}
		}
		cancel()
		<-writerDone
	}, websocket.Config{EnableCompression: true}))
	app.Get("/*", func(c fiber.Ctx) error {
		name := filepath.Clean(filepath.FromSlash("/" + c.Params("*")))
		name = strings.TrimLeft(name, "/\\")
		path := filepath.Join(webRoot, name)
		if st, err := os.Stat(path); err == nil && !st.IsDir() {
			return c.SendFile(path)
		}
		return c.SendFile(filepath.Join(webRoot, "index.html"))
	})
	return app
}
