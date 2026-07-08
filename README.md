# Claude Code Metrics Stack

Claude Code の OpenTelemetry メトリクスとイベントを収集し、Prometheus、Loki、Grafana で可視化するための最小構成です。現状の同梱設定は localhost 上の Docker 配置を前提にしていますが、将来的なリモート配置へ拡張しやすい構成にしています。記事の Tailscale 前提は使わず、`https://localhost:4318/v1/metrics` と `https://localhost:4318/v1/logs` へ `OTLP/HTTP + Bearer` で送信します。

本構成は [Claude Code で OpenTelemetry を使う](https://yag.xyz/post/claude-code-otel/) を参考にして作成しました。

## Stack

- Caddy: TLS 終端と Bearer 認証
- OpenTelemetry Collector: OTLP/HTTP 受信と Prometheus exporter
- Prometheus: メトリクス保存
- Loki: イベント保存
- Grafana: ダッシュボード可視化

## Quick Start

1. `.env.example` を `.env` にコピーして `INGEST_TOKEN` などを設定します。
2. `./scripts/generate-local-certs.sh` を実行して `mkcert` のローカル証明書を生成します。
3. `docker compose up -d` で起動します。
4. Grafana を `http://localhost:13000` で開きます。

詳しい手順は [docs/setup.md](docs/setup.md) を参照してください。

## Claude Code Settings

`~/.claude/settings.json` の `env` に次を追加します。

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

`OTEL_LOG_TOOL_DETAILS=1` を付けると、skill、subagent、MCP/GitHub 操作のイベント属性がより分かりやすくなります。

## Endpoints

- OTLP metrics ingest: `https://localhost:4318/v1/metrics`
- OTLP logs ingest: `https://localhost:4318/v1/logs`
- Prometheus UI: `http://localhost:19090`
- Loki API: `http://localhost:13100`
- Grafana UI: `http://localhost:13000`

## ポート衝突の対処

`docker compose up -d` 実行時に `bind: address already in use` が出た場合、別プロセスがそのポートを使用しています。

**使用中のプロセスを確認する**

```bash
lsof -iTCP:<ポート番号> -sTCP:LISTEN
```

**ポートを変更する**

`docker-compose.yml` の該当サービスの `ports` 行を編集します。形式は `"127.0.0.1:<ホスト側ポート>:<コンテナ内ポート>"` です。ホスト側ポートのみ変更してください。

例: Grafana を 13000 から 14000 に変更する場合

```yaml
ports:
  - "127.0.0.1:14000:3000"
```

変更後は README の Endpoints と、Claude Code の `OTEL_EXPORTER_OTLP_ENDPOINT`（4318 を変更した場合のみ）も合わせて更新してください。

## Validation Hints

- TLS 確認: `curl --silent https://localhost:4318/healthz`
- 認証失敗確認: `curl -i https://localhost:4318/v1/metrics`
- 認証通過確認: `curl -i -H "Authorization: Bearer <INGEST_TOKEN>" -H "Content-Type: application/json" -d '{}' https://localhost:4318/v1/metrics`

## Dashboards

- `Claude Code Metrics Overview`: 標準メトリクスと属性ベース分析
- `Claude Code Events Analysis`: skill activation、tool result、MCP/GitHub 操作、prompt length、input tokens などのイベント分析

注意:
- `skill`、`subagent`、`MCP/GitHub操作` は主にイベントまたは属性ベースの分析です。
- `セッションごとのコンテキストサイズ` は Claude Code の標準テレメトリでは直接取れないため、この構成では `prompt_length` と `input_tokens` を近似値として扱います。

Bearer 付きの空 JSON は Collector 側で `400` になる想定です。これは Caddy の認証を通って Collector まで到達した確認に使えます。
