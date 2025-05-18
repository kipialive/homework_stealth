from fastapi import FastAPI, Query, Response
import requests
import os
from prometheus_client import Counter, generate_latest
from fastapi.responses import JSONResponse
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# Tracing setup
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)
span_processor = BatchSpanProcessor(
    OTLPSpanExporter(endpoint="http://otel-collector-proxy.monitoring.svc.cluster.local:4318/v1/traces")
)
trace.get_tracer_provider().add_span_processor(span_processor)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)

ILS = os.getenv("ILS", "not set")
USD = os.getenv("USD", "not set")
BITCOIN_API_URL = os.getenv("BITCOIN_API_URL", "https://api.coingecko.com/api/v3/simple/price")

REQUEST_COUNTER = Counter("price_requests_total", "Total number of price requests")


@app.get("/healthz")
def health_check():
    return {"status": "ok"}


@app.get("/price")
def get_crypto_price(crypto: str = Query("bitcoin", description="Cryptocurrency name")):
    REQUEST_COUNTER.inc()
    try:
        params = {"ids": crypto, "vs_currencies": "usd"}
        response = requests.get(BITCOIN_API_URL, params=params, timeout=5)
        response.raise_for_status()
        data = response.json()
        if crypto not in data:
            return JSONResponse(status_code=404, content={"error": f"Price not found for '{crypto}'"})
        return {"crypto": crypto, "price_usd": data[crypto]["usd"], "ILS": ILS, "USD": USD}
    except requests.exceptions.RequestException as e:
        return JSONResponse(status_code=503, content={"error": "External API error", "details": str(e)})


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type="text/plain")

@app.get("/trace-test")
def trace_test():
    with tracer.start_as_current_span("manual-span"):
        return {"message": "trace manually triggered"}