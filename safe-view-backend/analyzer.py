# 핵심 분석 로직(Docker, Selenium) 담당

import asyncio
import time

import docker
from selenium import webdriver
from selenium.common.exceptions import WebDriverException
from services import GeminiService, ShodanService, VirusTotalService
from starlette.concurrency import run_in_threadpool  # 스레드 실행을 위해 임포트


class AnalysisRunner:
    def __init__(self, vt_service: VirusTotalService, shodan_service: ShodanService, gemini_service: GeminiService):
        self.vt_service = vt_service
        self.shodan_service = shodan_service
        self.gemini_service = gemini_service

    def _capture_screenshot(self, url: str, job_id: str) -> str:
        """Docker 컨테이너에서 스크린샷을 캡처합니다."""
        client = docker.from_env()
        container = None
        try:
            image_name = "selenium/standalone-chromium:latest"
            container = client.containers.run(
                image_name,
                detach=True,
                ports={'4444/tcp': 4444},
                dns=['8.8.8.8']
            )
            time.sleep(5)
            
            driver = webdriver.Remote(command_executor='http://127.0.0.1:4444/wd/hub', options=webdriver.ChromeOptions())
            screenshot_filename = f"{job_id}.png"
            screenshot_path = f"static/screenshots/{screenshot_filename}"
            driver.get(url)
            driver.save_screenshot(screenshot_path)
            driver.quit()
            print(f"[{job_id}] 스크린샷 저장 완료: {screenshot_path}")
            return f"/static/screenshots/{screenshot_filename}"
        finally:
            if container:
                print(f"[{job_id}] 컨테이너 정리 중..."); container.stop(); container.remove(); print(f"[{job_id}] 컨테이너 정리 완료.")

    async def run_full_analysis(self, job_id: str, url: str, jobs: dict) -> dict:
        """전체 분석 파이프라인을 실행합니다."""
        try:
            # 스크린샷 캡처
            jobs[job_id].update({'progress': 0.3, 'step': 'Capturing screenshot...'})
            # blocking 함수를 별도의 스레드에서 실행하여 메인 프로세스 멈춤을 방지
            screenshot_url_path = await run_in_threadpool(self._capture_screenshot, url, job_id)

            # VirusTotal URL 분석
            jobs[job_id].update({'progress': 0.6, 'step': 'Analyzing with VirusTotal...'})
            analysis_id = self.vt_service.analyze_url(url)
            await asyncio.sleep(15)
            report_data = self.vt_service.get_analysis_report(analysis_id)
            
            final_stats = report_data['data']['attributes']['stats']
            vendor_results = [{"vendor_name": k, "category": v.get("category"), "result": v.get("result")} for k, v in report_data['data']['attributes']['results'].items()]
            ip_address = report_data['data']['attributes'].get('ip_address')
            print(f"[{job_id}] VirusTotal URL 리포트에서 IP 주소 확인: {ip_address}")

            if not ip_address:
                ip_address = self.vt_service.get_domain_ip(url)
                print(f"[{job_id}] VirusTotal 도메인 리포트에서 IP 주소 확인: {ip_address}")

            # Shodan IP 분석
            jobs[job_id].update({'progress': 0.7, 'step': 'Analyzing IP with Shodan...'})
            shodan_info = self.shodan_service.get_host_info(ip_address) if ip_address else {"error": "No IP found"}

            # Gemini 요약 생성
            jobs[job_id].update({'progress': 0.8, 'step': 'Generating AI summary...'})
            gemini_summary = await self.gemini_service.generate_summary(vendor_results, shodan_info)
            
            # 최종 결과 조합
            malicious_count = final_stats.get('malicious', 0)
            return {
                "request_url": url,
                "screenshot_url": screenshot_url_path,
                "activity_log": [{"timestamp": time.strftime('%H:%M:%S'), "event": f"Navigation to {url} inside sandbox"}],
                "report": {
                    "risk_level": "High" if malicious_count > 0 else "Info",
                    "stats": final_stats,
                    "vendor_results": vendor_results,
                    "gemini_summary": gemini_summary,
                    "geo_info": shodan_info
                }
            }
        except WebDriverException as e:
            raise Exception(f"URL을 찾을 수 없거나 유효하지 않습니다: {e.msg}")
        except Exception as e:
            raise Exception(f"An unexpected error occurred: {e}")