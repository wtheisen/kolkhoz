from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

from .runtime import GameRuntime
from .store import GameNotFound, RevisionConflict, SQLiteEventStore


class Gateway(ThreadingHTTPServer):
    def __init__(self, address: tuple[str, int], runtime: GameRuntime) -> None:
        self.runtime = runtime
        super().__init__(address, GatewayHandler)


class GatewayHandler(BaseHTTPRequestHandler):
    server: Gateway

    def do_GET(self) -> None:
        self._dispatch(self._get)

    def _get(self) -> None:
        parts = [part for part in urlsplit(self.path).path.split("/") if part]
        if len(parts) == 2 and parts[0] == "games":
            self._respond(self.server.runtime.state(parts[1]))
            return
        self._send({"error": "not found"}, HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        self._dispatch(self._post)

    def _post(self) -> None:
        parts = [part for part in urlsplit(self.path).path.split("/") if part]
        body = self._body()
        if parts == ["games"]:
            self._respond(
                self.server.runtime.create_game(
                    seed=int(body.get("seed", 0)),
                    variants=body.get("variants") if isinstance(body.get("variants"), dict) else {},
                ),
                HTTPStatus.CREATED,
            )
            return
        if len(parts) == 3 and parts[0] == "games" and parts[2] == "actions":
            action = body.get("action")
            if not isinstance(action, dict):
                self._send({"error": "missing action"}, HTTPStatus.BAD_REQUEST)
                return
            self._respond(
                self.server.runtime.submit_action(
                    parts[1],
                    expected_revision=int(body.get("expectedRevision", -1)),
                    action=action,
                )
            )
            return
        self._send({"error": "not found"}, HTTPStatus.NOT_FOUND)

    def _dispatch(self, operation: object) -> None:
        try:
            operation()  # type: ignore[operator]
        except RevisionConflict as error:
            self._send(
                {"error": str(error), "currentRevision": error.actual},
                HTTPStatus.CONFLICT,
            )
        except GameNotFound:
            self._send({"error": "game not found"}, HTTPStatus.NOT_FOUND)
        except (KeyError, TypeError, ValueError) as error:
            self._send({"error": str(error)}, HTTPStatus.BAD_REQUEST)

    def _respond(self, operation: object, status: HTTPStatus = HTTPStatus.OK) -> None:
        self._send(asdict(operation), status)

    def _body(self) -> dict[str, object]:
        length = int(self.headers.get("content-length", "0"))
        value = json.loads(self.rfile.read(length) or b"{}")
        return value if isinstance(value, dict) else {}

    def _send(self, value: object, status: HTTPStatus) -> None:
        body = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8790)
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--shards", type=int, default=8)
    args = parser.parse_args()
    runtime = GameRuntime(SQLiteEventStore(args.database), shard_count=args.shards)
    server = Gateway((args.host, args.port), runtime)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        runtime.close()


if __name__ == "__main__":
    main()
