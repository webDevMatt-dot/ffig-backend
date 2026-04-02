from django.contrib import admin
from .models import Poll, PollOption, PollVote, QuizQuestion, QuizSubmission

class PollOptionInline(admin.TabularInline):
    model = PollOption
    extra = 1

@admin.register(Poll)
class PollAdmin(admin.ModelAdmin):
    list_display = ('question', 'created_at', 'expires_at', 'is_active')
    inlines = [PollOptionInline]

@admin.register(QuizQuestion)
class QuizQuestionAdmin(admin.ModelAdmin):
    list_display = ('prompt', 'created_at', 'expires_at', 'is_active')

@admin.register(PollVote)
class PollVoteAdmin(admin.ModelAdmin):
    list_display = ('user', 'poll', 'option', 'created_at')
    list_filter = ('poll',)

@admin.register(QuizSubmission)
class QuizSubmissionAdmin(admin.ModelAdmin):
    list_display = ('user', 'quiz_question', 'selected_index', 'created_at')
    list_filter = ('quiz_question',)
