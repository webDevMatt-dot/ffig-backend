import os
import django
from django.utils import timezone
from datetime import timedelta

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ffig_backend.settings")
django.setup()

from community.models import Poll, PollOption, QuizQuestion

def seed_community():
    print("🌱 Seeding Community Data...")
    
    # 1. Clear existing (Optional for testing)
    Poll.objects.all().delete()
    QuizQuestion.objects.all().delete()
    
    # 2. Create a Poll
    poll1 = Poll.objects.create(
        question="Which masterclass topic should we host next?",
        expires_at=timezone.now() + timedelta(days=7)
    )
    PollOption.objects.create(poll=poll1, label="Venture Capital Strategies", vote_count=12)
    PollOption.objects.create(poll=poll1, label="Personal Branding for Founders", vote_count=45)
    PollOption.objects.create(poll=poll1, label="Scaling Operations", vote_count=23)
    
    poll2 = Poll.objects.create(
        question="Preferred day for weekly networking?",
        expires_at=timezone.now() + timedelta(days=3)
    )
    PollOption.objects.create(poll=poll2, label="Tuesday Morning", vote_count=5)
    PollOption.objects.create(poll=poll2, label="Thursday Evening", vote_count=18)
    
    # 3. Create a Quiz Question
    QuizQuestion.objects.create(
        prompt="What is the most critical metric for early-stage Product-Market Fit?",
        options=["Total Downloads", "Customer Retention/Cohort Stickiness", "Social Media Followers"],
        correct_index=1,
        explanation="Retention shows whether users are actually deriving value and returning to your product.",
        expires_at=timezone.now() + timedelta(days=5)
    )
    
    QuizQuestion.objects.create(
        prompt="Which of these is a 'Vanity Metric'?",
        options=["Customer Acquisition Cost (CAC)", "Monthly Active Users (MAU)", "Total Cumulative Signups"],
        correct_index=2,
        explanation="Cumulative signups always go up and don't reflect current engagement or churn.",
        expires_at=timezone.now() + timedelta(days=10)
    )
    
    print("✅ Community Seeding Complete!")

if __name__ == "__main__":
    seed_community()
