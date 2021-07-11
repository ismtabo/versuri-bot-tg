package main

import (
	"context"
	"testing"

	"github.com/Telefonica/golium"
	"github.com/Telefonica/golium/steps/http"
	"github.com/cucumber/godog"
	"github.com/ismtabo/mapon-viewer/test/acceptance/steps"
)

func TestMain(m *testing.M) {
	launcher := golium.NewLauncher()
	launcher.Launch(InitializeTestSuite, InitializeScenario)
}

func InitializeTestSuite(ctx context.Context, suiteCtx *godog.TestSuiteContext) {
}

func InitializeScenario(ctx context.Context, scenarioCtx *godog.ScenarioContext) {
	stepsInitializers := []golium.StepsInitializer{
		http.Steps{},
		steps.ServerSteps{},
	}
	for _, stepsInitializer := range stepsInitializers {
		ctx = stepsInitializer.InitializeSteps(ctx, scenarioCtx)
	}
}
