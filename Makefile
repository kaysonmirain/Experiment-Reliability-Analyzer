.PHONY: data benchmark test all clean

data:
	Rscript R/generate_data.R

benchmark: data
	Rscript R/benchmark.R

test:
	Rscript tests/test_metrics.R

all: test benchmark

clean:
	rm -f data/experiment_events.csv results/*.csv results/*.png results/*.txt
