package main

import (
	"net/http"
	"os"
	"strings"

	"github.com/ismtabo/mapon-viewer/pkg/cfg"
	"github.com/rs/zerolog"
)

func main() {
	log := getLogger()
	var config Config
	if err := cfg.Load("config.yml", &config); err != nil {
		log.Fatal().Msgf("Error loading configuration. %s", err)
	}
	log.Debug().Msgf("Configuration loaded: %+v", config)
	if err := configLogger(&config); err != nil {
		log.Fatal().Msgf("Error configuring the logger. %s", err)
	}

	http.Handle("/", http.HandlerFunc(func(rw http.ResponseWriter, r *http.Request) {
		rw.Write([]byte("Hello World!"))
	}))
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal().Msg("Error starting server")
	}
}

func getLogger() *zerolog.Logger {
	zerolog.TimeFieldFormat = "2006-01-02T15:04:05.000Z07:00"
	zerolog.TimestampFieldName = "time"
	zerolog.LevelFieldName = "lvl"
	zerolog.MessageFieldName = "msg"
	log := zerolog.New(os.Stdout).With().Timestamp().Logger()
	return &log
}

func configLogger(config *Config) error {
	lvl, err := zerolog.ParseLevel(strings.ToLower(config.Log.Level))
	if err != nil {
		return err
	}
	zerolog.SetGlobalLevel(lvl)
	return nil
}
