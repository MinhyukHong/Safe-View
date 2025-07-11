# Pydantic 데이터 모델 관리

from pydantic import BaseModel


class UrlItem(BaseModel):
    url_to_analyze: str