# FastAPI 앱 설정과 라우팅 담당

import asyncio
import uuid
from datetime import datetime

from analyzer import AnalysisRunner
from bson import ObjectId
from fastapi import BackgroundTasks, FastAPI
from fastapi.staticfiles import StaticFiles
from models import UrlItem
from pymongo import DESCENDING, MongoClient
from services import GeminiService, ShodanService, VirusTotalService

# 설정
app = FastAPI()
jobs = {}
cache = {}

# API 키
VT_API_KEY = "YOUR KEY"
GEMINI_API_KEY = "YOUR KEY"
SHODAN_API_KEY = "YOUR KEY"

# 서비스 및 분석기 인스턴스 생성
vt_service = VirusTotalService(api_key=VT_API_KEY)
shodan_service = ShodanService(api_key=SHODAN_API_KEY)
gemini_service = GeminiService(api_key=GEMINI_API_KEY)
analysis_runner = AnalysisRunner(vt_service, shodan_service, gemini_service)

# DB 및 Static 폴더 설정
mongo_client = MongoClient('mongodb://localhost:27017/')
db = mongo_client['safe_view_db']
analyses_collection = db['analyses']
app.mount("/static", StaticFiles(directory="static"), name="static")

# 백그라운드 작업 함수
async def start_analysis_task(job_id: str, url: str):
    """백그라운드에서 전체 분석을 실행하고 결과를 처리하는 함수"""
    try:
        results = await analysis_runner.run_full_analysis(job_id, url, jobs)
        
        # 결과 DB 저장
        db_entry = results.copy()
        db_entry["analyzed_at"] = datetime.now()
        analyses_collection.insert_one(db_entry)
        print(f"[{job_id}] 분석 결과 DB 저장 완료")

        # 캐시 및 최종 상태 업데이트
        json_compatible_result = db_entry.copy()
        json_compatible_result["analyzed_at"] = json_compatible_result["analyzed_at"].isoformat()
        if '_id' in json_compatible_result:
             json_compatible_result['_id'] = str(json_compatible_result['_id'])

        cache[url] = json_compatible_result
        jobs[job_id].update({"status": "complete", "results": json_compatible_result})
        print(f"[{job_id}] 분석 완료 및 결과 캐싱")

    except Exception as e:
        print(f"[{job_id}] 분석 중 오류 발생: {e}")
        jobs[job_id].update({"status": "error", "message": str(e)})

# API 엔드포인트
@app.post("/analyze")
async def analyze_url(item: UrlItem, background_tasks: BackgroundTasks):
    job_id = str(uuid.uuid4())
    jobs[job_id] = {"status": "processing", "progress": 0.0, "step": "Request received"}
    
    if item.url_to_analyze in cache:
        print(f"캐시된 결과 반환: {item.url_to_analyze}")
        jobs[job_id].update({"status": 'complete', "progress": 1.0, "results": cache[item.url_to_analyze]})
    else:
        background_tasks.add_task(start_analysis_task, job_id, item.url_to_analyze)
    
    return {"job_id": job_id}

@app.get("/results/{job_id}")
async def get_results(job_id: str):
    return jobs.get(job_id, {"status": "error", "message": "Job ID not found."})

@app.get("/history")
async def get_history():
    history_cursor = analyses_collection.find({}).sort("analyzed_at", DESCENDING)
    results = []
    for doc in history_cursor:
        doc['_id'] = str(doc['_id'])
        if 'analyzed_at' in doc and isinstance(doc['analyzed_at'], datetime):
            doc['analyzed_at'] = doc['analyzed_at'].isoformat()
        results.append(doc)
    return results
