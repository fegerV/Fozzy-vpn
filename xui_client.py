import httpx
import json
from typing import Dict, List, Optional, Any
from config import settings
import base64
import uuid


class XUIClient:
    def __init__(self):
        self.base_url = settings.xui_panel_url
        self.username = settings.xui_username
        self.password = settings.xui_password
        self.session_id = None
        
    async def login(self) -> bool:
        """Аутентификация в 3x-ui панели"""
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.base_url}/login",
                    data={
                        "username": self.username,
                        "password": self.password
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if result.get("success"):
                        self.session_id = result.get("session")
                        return True
                return False
            except Exception as e:
                print(f"Login error: {e}")
                return False
    
    async def get_inbounds(self) -> Optional[List[Dict]]:
        """Получить список inbound правил"""
        if not self.session_id:
            await self.login()
            
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    f"{self.base_url}/panel/api/inbounds/list",
                    cookies={"session": self.session_id}
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if result.get("success"):
                        return result.get("obj", [])
                return None
            except Exception as e:
                print(f"Get inbounds error: {e}")
                return None
    
    async def add_client(self, email: str, days: int, data_limit_gb: int = None) -> Optional[Dict]:
        """Добавить нового VPN клиента"""
        if not self.session_id:
            await self.login()
            
        # Генерируем UUID для клиента
        client_id = str(uuid.uuid4())
        
        # Устанавливаем лимит данных
        if data_limit_gb is None:
            data_limit_gb = settings.default_data_limit_gb
            
        data_limit_bytes = data_limit_gb * 1024 * 1024 * 1024
        
        client_data = {
            "id": client_id,
            "email": email,
            "limitIp": 0,
            "totalGB": data_limit_bytes,
            "expiryTime": 0,  # Будет установлено через enable_client
            "enable": True,
            "tgId": "",
            "subId": ""
        }
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.base_url}/panel/api/inbounds/addClient",
                    cookies={"session": self.session_id},
                    json={
                        "id": settings.vpn_inbound_id,
                        "settings": json.dumps({
                            "clients": [client_data]
                        })
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if result.get("success"):
                        # Включаем клиент с указанием срока действия
                        await self.enable_client_with_expiry(client_id, days)
                        return {
                            "id": client_id,
                            "email": email,
                            "success": True
                        }
                return None
            except Exception as e:
                print(f"Add client error: {e}")
                return None
    
    async def enable_client_with_expiry(self, client_id: str, days: int) -> bool:
        """Включить клиент с указанием срока действия"""
        if not self.session_id:
            await self.login()
            
        import time
        expiry_time = int(time.time()) + (days * 24 * 60 * 60)
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.base_url}/panel/api/inbounds/updateClient",
                    cookies={"session": self.session_id},
                    json={
                        "id": settings.vpn_inbound_id,
                        "client": {
                            "id": client_id,
                            "enable": True,
                            "expiryTime": expiry_time
                        }
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    return result.get("success", False)
                return False
            except Exception as e:
                print(f"Enable client error: {e}")
                return False
    
    async def delete_client(self, email: str) -> bool:
        """Удалить VPN клиента"""
        if not self.session_id:
            await self.login()
            
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.base_url}/panel/api/inbounds/delClient",
                    cookies={"session": self.session_id},
                    json={
                        "id": settings.vpn_inbound_id,
                        "email": email
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    return result.get("success", False)
                return False
            except Exception as e:
                print(f"Delete client error: {e}")
                return False
    
    async def get_client_stats(self, email: str) -> Optional[Dict]:
        """Получить статистику клиента"""
        if not self.session_id:
            await self.login()
            
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    f"{self.base_url}/panel/api/inbounds/getClientTraffics/{email}",
                    cookies={"session": self.session_id}
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if result.get("success"):
                        return result.get("obj")
                return None
            except Exception as e:
                print(f"Get client stats error: {e}")
                return None
    
    async def get_client_config(self, email: str) -> Optional[str]:
        """Получить конфигурацию клиента"""
        if not self.session_id:
            await self.login()
            
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    f"{self.base_url}/panel/api/inbounds/genClientLink/{email}",
                    cookies={"session": self.session_id}
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if result.get("success"):
                        return result.get("obj")
                return None
            except Exception as e:
                print(f"Get client config error: {e}")
                return None