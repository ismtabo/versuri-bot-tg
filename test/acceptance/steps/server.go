package steps

import (
	"context"

	"github.com/Telefonica/golium"
	"github.com/Telefonica/golium/steps/http"
	"github.com/cucumber/godog"
	"github.com/pkg/errors"
)

type ServerSteps struct{}

func (s ServerSteps) InitializeSteps(ctx context.Context, scenCtx *godog.ScenarioContext) context.Context {
	// Retrieve HTTP session
	session := http.GetSession(ctx)
	// Initialize the steps
	scenCtx.Step(`^the HTTP response should not be empty$`, func() error {
		if err := session.ValidateResponseBodyEmpty(ctx); err == nil {
			return errors.New("error: HTTP response is empty")
		}
		return nil
	})
	scenCtx.Step(`^the HTTP response should containt the text$`, func(t *godog.DocString) error {
		body := golium.ValueAsString(ctx, t.Content)
		return ValidateResponseTextContent(ctx, body)
	})
	return ctx
}

func ValidateResponseTextContent(ctx context.Context, expected string) error {
	session := http.GetSession(ctx)
	actual := string(session.Response.ResponseBody)
	if expected != actual {
		return errors.Errorf("failed validating response text body: expected '%s' actual '%s'", expected, actual)
	}
	return nil
}
