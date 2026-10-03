package main

import (
	"blackbox/internal/engine"
	"blackbox/internal/server"
	"blackbox/internal/storage"
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func run() error {
	addr := flag.String("addr", "127.0.0.1:8080", "listen address")
	db := flag.String("db", "data/blackbox.db", "SQLite file")
	web := flag.String("web", "../frontend/dist", "compiled frontend directory")
	flag.Parse()
	store, err := storage.Open(*db)
	if err != nil {
		return err
	}
	defer store.Close()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	game, err := engine.New(ctx, store)
	if err != nil {
		return err
	}
	go game.Run(ctx)
	app := server.New(game, *web)
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-signals
		cancel()
		game.Wait()
		if err := app.ShutdownWithTimeout(5 * time.Second); err != nil {
			log.Print(err)
		}
	}()
	log.Printf("Black Box: http://%s · SQLite %s", *addr, *db)
	if err = app.Listen(*addr); err != nil {
		log.Print(err)
	}
	cancel()
	game.Wait()
	return err
}

func main() {
	if err := run(); err != nil {
		log.Print(err)
		os.Exit(1)
	}
}
