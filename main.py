from fastapi import FastAPI
from supabase import create_client, Client
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# 1. CORS 설정 (앱에서 서버로 접속 허용)
# 보안상 나중에는 특정 주소만 허용해야 하지만, MVP 단계에서는 모두 허용(*)합니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Supabase 연결 정보 (사장님의 키를 직접 입력함)
# 주소 앞에 https:// 붙이고, 뒤에 .supabase.co 붙여서 완성했습니다.
SUPABASE_URL = "https://zwiglohkzohjjcjfxsvr.supabase.co"

# API Key (ANON KEY)
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp3aWdsb2hrem9oampjamZ4c3ZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwODYwNTcsImV4cCI6MjA4MjY2MjA1N30.Z5edgxUokEohhf1tLa6PbqKUqlLsHqVSl7MUK7_9jpA"

# 3. Supabase 클라이언트 생성 (오류 방지용 예외처리 추가)
try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("✅ Pinda(핀다) 데이터베이스 연결 성공!")
except Exception as e:
    print(f"❌ 데이터베이스 연결 실패: {e}")

# --- 여기서부터 API 주소(엔드포인트) 정의 ---

@app.get("/")
def read_root():
    # 서버가 살아있는지 확인할 때 뜨는 메시지입니다.
    return {"message": "Pinda Server is Running!"}

@app.get("/pins")
def get_pins():
    # Supabase의 'pins' 테이블에 있는 모든 핀 정보를 가져옵니다.
    try:
        response = supabase.table("pins").select("*").execute()
        return response.data
    except Exception as e:
        return {"error": f"핀 정보를 가져오는데 실패했습니다: {str(e)}"}

# (선택사항) 핀 정보를 저장하는 기능
@app.post("/pins")
def create_pin(pin: dict):
    try:
        response = supabase.table("pins").insert(pin).execute()
        return response.data
    except Exception as e:
        return {"error": f"핀 저장 실패: {str(e)}"}