import os
import socket
from contextlib import closing

import pymysql
from fastapi import FastAPI, HTTPException

# FastAPI 객체 생성
app = FastAPI(title="DE-AI-22 EKS Auto Mode WAS", version="1.0.0-auto")

# 일반 커스텀 함수
def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def db_connection():
    return pymysql.connect(
        host=required_env("DB_HOST"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=required_env("DB_USER"),
        password=required_env("DB_PASSWORD"),
        database=required_env("DB_NAME"),
        connect_timeout=5,
        read_timeout=5,
        write_timeout=5,
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )

# 라우팅 함수 was/pod의 헬스체크
@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

# web -> was (로그벨런서가 작동중인지 확인 가능 : host name으로)
@app.get("/api/info")
def info() -> dict[str, str]:
    return {
        "message": "WEB Pod에서 WAS Service로 정상 연결되었습니다.",
        "was_pod": socket.gethostname(), # was service에 의해 a존 , c존 특정 pod에 응답
        "version": "v3-eks-auto",
    }

# web -> was -> rds
@app.get("/api/db")
def db_test() -> dict:
    try:
        # I/O -> 반드시 사용후 close() 해야함 -> 자동처리 -> with문
        with closing(db_connection()) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    # 요청 기록을 저장하는 테이블 생성
                    """
                    CREATE TABLE IF NOT EXISTS request_counter (
                        id BIGINT AUTO_INCREMENT PRIMARY KEY,
                        pod_name VARCHAR(255) NOT NULL,
                        requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """
                )
                # 요청에 대한 로그 기록
                cursor.execute(
                    "INSERT INTO request_counter (pod_name) VALUES (%s)",
                    (socket.gethostname(),),
                )
                # 현재 DB 시간 기준 총 col 수, DB 시간 쿼리
                cursor.execute(
                    "SELECT COUNT(*) AS total_requests, NOW() AS database_time FROM request_counter"
                )
                # 조회 결과 1개만 획득
                result = cursor.fetchone()

        return {
            "message": "WAS Pod에서 RDS MySQL로 정상 연결되었습니다.",
            "was_pod": socket.gethostname(),
            **result,
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"RDS connection failed: {exc}") from exc