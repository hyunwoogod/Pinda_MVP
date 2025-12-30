from fastapi import FastAPI
from supabase import create_client, Client
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI()

# 1. CORS 설정 (프론트엔드에서 접속 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 모든 곳에서 접속 허용 (보안상 나중엔 Vercel 주소만 넣어야 함)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Supabase 연결 (환경변수에서 가져옴)
# Render 설정에서 입력할 값들입니다.
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

@app.get("/")
def read_root():
    return {"message": "NowHere Server is Running!"}

@app.get("/pins")
def get_pins():
    # Supabase의 'pins' 테이블 모든 데이터 가져오기
    response = supabase.table("pins").select("*").execute()
    return response.data