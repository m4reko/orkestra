from dataclasses import dataclass
from pathlib import Path

from flask import Flask


@dataclass(frozen=True)
class AppConfig:
    database: str

    @staticmethod
    def from_app(app: Flask) -> "AppConfig":
        database: object = app.config["DATABASE"]  # pyright: ignore[reportUnknownMemberType, reportUnknownVariableType]
        if not isinstance(database, str):
            msg = "DATABASE config must be a string"
            raise TypeError(msg)
        return AppConfig(database=database)

    def apply(self, app: Flask) -> None:
        app.config["DATABASE"] = self.database

    @staticmethod
    def default(app: Flask) -> "AppConfig":
        return AppConfig(
            database=str(Path(app.instance_path) / "orchestra.db"),
        )
