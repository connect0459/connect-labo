"""作業時間計算ロジック"""

from datetime import datetime, timedelta

from .config import Config


class WorkHoursCalculator:
    """作業時間計算クラス"""

    def __init__(self, config: Config):
        """初期化

        Args:
            config: アプリケーション設定
        """
        self.config = config

    def is_workday(self, dt: datetime) -> bool:
        """営業日（平日かつ祝日でない）かどうか判定

        Args:
            dt: 判定対象の日時

        Returns:
            営業日の場合True
        """
        # 土日を除外
        if dt.weekday() >= 5:  # 5=土曜, 6=日曜
            return False

        # 祝日を除外
        date_only = datetime(dt.year, dt.month, dt.day)
        if date_only in self.config.holidays:
            return False

        return True

    def calculate_work_hours(self, start_dt: datetime, end_dt: datetime) -> float:
        """開始時刻から終了時刻までの稼働時間を計算（平日の勤務時間のみ）

        Args:
            start_dt: 開始時刻（JST）
            end_dt: 終了時刻（JST）

        Returns:
            稼働時間（時間単位、小数点以下2桁）
        """
        if start_dt >= end_dt:
            return 0.0

        wh = self.config.work_hours
        total_minutes = 0
        current = start_dt.replace(second=0, microsecond=0)

        while current < end_dt:
            # 営業日でない場合はスキップ
            if not self.is_workday(current):
                # 次の日の開始時刻に進める
                current = datetime(
                    current.year, current.month, current.day
                ) + timedelta(days=1)
                current = current.replace(hour=wh.start_hour, minute=wh.start_minute)
                continue

            # その日の勤務開始・終了時刻
            day_start = current.replace(hour=wh.start_hour, minute=wh.start_minute)
            day_end = current.replace(hour=wh.end_hour, minute=wh.end_minute)

            # その日の作業開始時刻（currentと勤務開始時刻の遅い方）
            work_start = max(current, day_start)

            # その日の作業終了時刻（end_dtと勤務終了時刻の早い方）
            work_end = min(end_dt, day_end)

            # その日の稼働時間を加算
            if work_start < work_end:
                minutes = (work_end - work_start).total_seconds() / 60
                total_minutes += minutes

            # 次の日の開始時刻に進める
            current = datetime(current.year, current.month, current.day) + timedelta(
                days=1
            )
            current = current.replace(hour=wh.start_hour, minute=wh.start_minute)

        return round(total_minutes / 60, 2)

    @staticmethod
    def format_hours(hours: float) -> str:
        """時間を整形（0.5時間 -> 30分、1.0時間 -> 1時間）

        Args:
            hours: 時間（小数）

        Returns:
            整形された時間文字列
        """
        if hours == 0:
            return "0分"

        total_minutes = int(hours * 60)
        h = total_minutes // 60
        m = total_minutes % 60

        if h > 0 and m > 0:
            return f"{h}時間{m}分"
        elif h > 0:
            return f"{h}時間"
        else:
            return f"{m}分"

    @staticmethod
    def utc_to_jst(utc_str: str) -> datetime:
        """UTC時刻文字列をJSTのdatetimeオブジェクトに変換

        Args:
            utc_str: UTC時刻文字列（ISO 8601形式）

        Returns:
            JSTのdatetimeオブジェクト
        """
        utc_dt = datetime.fromisoformat(utc_str.replace("Z", "+00:00"))
        jst_dt = utc_dt + timedelta(hours=9)
        return jst_dt.replace(tzinfo=None)
