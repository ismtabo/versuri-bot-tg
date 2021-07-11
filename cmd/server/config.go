package main

type Config struct {
	Server struct {
		Host string `yml:"host" envconfig:"SERVER_HOST"`
		Port string `yml:"port" envconfig:"SERVER_PORT"`
	} `yml:"server"`
	Log struct {
		Level string `yml:"level" envconfig:"LOG_LEVEL"`
	} `yml:"log"`
}
