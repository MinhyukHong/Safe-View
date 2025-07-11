# 외부 API 연동 로직 관리

import requests
import shodan
import google.generativeai as genai
from urllib.parse import urlparse

class GeminiService:
    def __init__(self, api_key: str):
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel('gemini-1.5-flash-latest')

    async def generate_summary(self, vendor_results: list, shodan_info: dict) -> str:
        try:
            malicious_reports = [f"- {item['vendor_name']}: {item['result']}" for item in vendor_results if item['category'] == 'malicious']
            if not malicious_reports:
                return "여러 보안 업체의 검사 결과, 특별한 위협이 발견되지 않았습니다. 하지만 링크를 열 때는 항상 주의하시기 바랍니다."

            country = shodan_info.get('country_name')
            city = shodan_info.get('city')
            location_info = ""
            if country:
                location_info = f"참고로 이 사이트의 서버는 {country}"
                if city:
                    location_info += f" {city}"
                location_info += "에 위치해 있습니다."

            prompt = f"""
            당신은 일반인도 이해하기 쉽게 설명하는 사이버 보안 전문가입니다.
            아래는 특정 URL에 대한 분석 결과입니다. 이 내용을 종합해서, 해당 URL에 접속했을 때 어떤 위험이 있는지 한 문단으로 요약해서 설명해주세요.

            [악성 판단 내용]
            {'\n'.join(malicious_reports)}

            [서버 위치 정보]
            {location_info if location_info else "위치 정보 없음"}
            """
            
            print("--- Gemini API 요청 시작 ---")
            print(f"Prompt:\n{prompt}") # 디버깅을 위해 프롬프트 내용 출력

            try:
                response = await self.model.generate_content_async(
                    prompt,
                    request_options={"timeout": 45} # 타임아웃을 45초로 줄여서 빠른 실패 확인
                )
                print("--- Gemini API 응답 수신 완료 ---")
                return response.text
            except Exception as api_error:
                # API 호출 자체에서 발생하는 오류 (타임아웃, 인증 실패 등)
                print(f"!!! Gemini API 호출 실패: {api_error}")
                return f"AI 요약 보고서 생성 중 오류가 발생했습니다. (API 호출 실패: {type(api_error).__name__})"

        except Exception as e:
            # 프롬프트 생성 등 다른 로직에서 발생하는 오류
            print(f"!!! Gemini 요약 생성 중 전체적인 오류 발생: {e}")
            return "AI 요약 보고서를 생성하는 데 실패했습니다."


class VirusTotalService:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.headers = {'x-apikey': self.api_key}
        self.base_url = 'https://www.virustotal.com/api/v3'

    def analyze_url(self, url: str) -> dict:
        """URL을 분석하고 분석 ID를 반환합니다."""
        response = requests.post(f'{self.base_url}/urls', headers=self.headers, data={'url': url})
        response.raise_for_status()
        return response.json()['data']['id']

    def get_analysis_report(self, analysis_id: str) -> dict:
        """분석 ID로 리포트를 가져옵니다."""
        report_url = f'{self.base_url}/analyses/{analysis_id}'
        response = requests.get(report_url, headers=self.headers)
        response.raise_for_status()
        return response.json()

    def get_domain_ip(self, url: str) -> str | None:
        """URL에서 도메인을 추출하여 IP 주소를 조회합니다."""
        try:
            parsed_url = urlparse(url)
            domain = parsed_url.netloc
            if not domain:
                return None

            domain_report_url = f'{self.base_url}/domains/{domain}'
            response = requests.get(domain_report_url, headers=self.headers)
            response.raise_for_status()
            domain_data = response.json()
            
            dns_records = domain_data.get('data', {}).get('attributes', {}).get('last_dns_records', [])
            for record in dns_records:
                if record.get('type') == 'A':
                    return record.get('value')
            return None
        except Exception as e:
            print(f"VirusTotal 도메인 리포트 조회 중 오류: {e}")
            return None

class ShodanService:
    def __init__(self, api_key: str):
        self.api = shodan.Shodan(api_key)

    def get_host_info(self, ip_address: str) -> dict:
        """IP 주소로 호스트 정보를 가져옵니다."""
        try:
            host_info = self.api.host(ip_address)
            return {
                "ip": host_info.get('ip_str'),
                "country_name": host_info.get('country_name'),
                "city": host_info.get('city'),
                "latitude": host_info.get('latitude'),
                "longitude": host_info.get('longitude'),
            }
        except Exception as e:
            print(f"Shodan 오류: {e}")
            return {"error": "Could not retrieve Shodan data."}