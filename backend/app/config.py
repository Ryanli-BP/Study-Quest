from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    anthropic_api_key: str
    secret_key: str = "dev-secret-key-change-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 days
    database_url: str = "sqlite+aiosqlite:///./app.db"
    upload_dir: str = "./uploads"

    # Token rewards
    lesson_complete_reward: int = 10
    quiz_complete_reward: int = 25
    quiz_perfect_score_bonus: int = 15  # extra tokens for 100% score

    # Gacha costs
    single_pull_cost: int = 50
    ten_pull_cost: int = 450  # 10 pulls for the price of 9

    class Config:
        env_file = ".env"


settings = Settings()
