# Generate inst/extdata/embraceplus_sample.avro (a minimal EmbracePlus-schema
# Avro container) via the Python fastavro module through reticulate.
library(reticulate)
fastavro <- import("fastavro")
json <- import("json")
builtins <- import_builtins()

scalar <- function(name) sprintf(
  '{"type":"record","name":"%s","fields":[
     {"name":"samplingFrequency","type":"float"},
     {"name":"timestampStart","type":"long"},
     {"name":"values","type":{"type":"array","items":"float"}}]}', name)

schema_json <- sprintf('{
  "type":"record","name":"EmbracePlusData","fields":[
    {"name":"rawData","type":{"type":"record","name":"RawData","fields":[
      {"name":"eda","type":%s},
      {"name":"bvp","type":%s},
      {"name":"temperature","type":%s},
      {"name":"accelerometer","type":{"type":"record","name":"Accelerometer","fields":[
        {"name":"samplingFrequency","type":"float"},
        {"name":"timestampStart","type":"long"},
        {"name":"x","type":{"type":"array","items":"int"}},
        {"name":"y","type":{"type":"array","items":"int"}},
        {"name":"z","type":{"type":"array","items":"int"}}]}}]}}]}',
  scalar("Eda"), scalar("Bvp"), scalar("Temperature"))

schema <- fastavro$parse_schema(json$loads(schema_json))

t0 <- 1700000000000000  # microseconds
records <- list(list(rawData = list(
  eda = list(samplingFrequency = 4, timestampStart = t0,
             values = c(0.50, 0.51, 0.52, 0.53)),
  bvp = list(samplingFrequency = 64, timestampStart = t0,
             values = c(1, 2, 3, 4)),
  temperature = list(samplingFrequency = 1, timestampStart = t0 + 2000000,
                     values = c(31.5, 31.6)),
  accelerometer = list(samplingFrequency = 32, timestampStart = t0,
                       x = c(1L, 2L), y = c(3L, 4L), z = c(5L, 6L)))))

out <- "inst/extdata/embraceplus_sample.avro"
con <- builtins$open(out, "wb")
fastavro$writer(con, schema, records)
con$close()
cat("wrote", out, "\n")
