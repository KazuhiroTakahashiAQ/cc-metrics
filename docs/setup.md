# Setup

## Prerequisites

- Docker Desktop または Docker Engine + Compose
- `mkcert`
- Claude Code

macOS で `mkcert` を入れる例:

```bash
brew install mkcert
brew install nss # Firefox も信頼させたい場合
```

## 1. Environment File

`.env.example` を `.env` にコピーして値を設定します。

```bash
cp .env.example .env
```

最低限、`INGEST_TOKEN` は長いランダム文字列に置き換えてください。

## 2. Generate TLS Certificates

```bash
./scripts/generate-local-certs.sh
```

このスクリプトは `mkcert -install` を実行したうえで、以下のファイルを生成します。

- `certs/localhost.pem`
- `certs/localhost-key.pem`

## 3. Start the Metrics Stack

```bash
docker compose up -d
```

利用ポート:

- `4318`: HTTPS OTLP ingest
- `9090`: Prometheus
- `3000`: Grafana

いずれも `127.0.0.1` にだけ bind されます。

## 4. Configure Claude Code

`~/.claude/settings.json` に次の `env` を追加します。

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "https://localhost:4318",
    "OTEL_EXPORTER_OTLP_HEADERS": "Authorization=Bearer <INGEST_TOKEN>",
    "OTEL_RESOURCE_ATTRIBUTES": "host.name=<hostname>",
    "OTEL_LOG_TOOL_DETAILS": "1"
  }
}
```

`<INGEST_TOKEN>` は `.env` の値に置き換えてください。`<hostname>` は手元の端末名や用途名で十分です。`OTEL_LOG_TOOL_DETAILS=1` は skill、subagent、MCP/GitHub 操作の詳細属性を見たい場合に推奨です。

## 5. Validate

### Docker Compose 設定の確認

```bash
docker compose config
```

### TLS の確認

```bash
curl --silent https://localhost:4318/healthz
```

`mkcert` を正しく trust できていれば TLS エラーになりません。

### Bearer 認証の確認

Bearer なし:

```bash
curl -i https://localhost:4318/v1/metrics
```

期待値: `401 Unauthorized`

Bearer あり:

```bash
curl -i \
  -H "Authorization: Bearer ${INGEST_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}' \
  https://localhost:4318/v1/metrics
```

期待値: `400` 系。空 JSON は無効な OTLP ペイロードなので Collector が拒否します。これは認証後に Collector へ到達した確認になります。

### Prometheus 確認

`http://localhost:9090/targets` で `otel-collector` が `UP` になっていることを確認します。

### Grafana 確認

`http://localhost:3000` にアクセスし、Provisioning 済みの `Claude Code Metrics Overview` と `Claude Code Events Analysis` ダッシュボードが見えることを確認します。

## Notes

- この構成はメトリクスを Prometheus、イベントを Loki に送ります。
- Prometheus の保存先は Docker volume です。
- Loki の保存先は Docker volume です。
- Collector は resource attributes を Prometheus label に変換するので、`host.name` は通常 `host_name` ラベルとして参照できます。
- `prompt_length` と `input_tokens` は「セッションコンテキストサイズ」の近似として扱います。Claude Code の標準テレメトリには、コンテキスト窓全体の厳密サイズを直接出す専用メトリクスはありません。
