package cfg

import (
	"os"

	"github.com/kelseyhightower/envconfig"
	"gopkg.in/yaml.v3"
)

// Load reads the configuration from a yml file (at path) and from
// environment variables.
func Load(path string, config interface{}) error {
	if err := LoadYaml(path, config); err != nil {
		return err
	}
	return LoadEnv(config)
}

// LoadYaml reads a yaml file at path in the config struct.
func LoadYaml(path string, config interface{}) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	decoder := yaml.NewDecoder(f)
	return decoder.Decode(config)
}

// LoadEnv loads the environment variables into config struct.
func LoadEnv(config interface{}) error {
	return envconfig.Process("", config)
}
