from django.db import models

class Resource(models.Model):
    RESOURCE_TYPES = [
        ('MAGAZINE', 'Magazine'),
        ('MASTERCLASS', 'Masterclass'),
        ('NEWSLETTER', 'Newsletter'),
        ('TOOLKIT', 'Business Toolkit'),
    ]

    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    resource_type = models.CharField(max_length=20, choices=RESOURCE_TYPES)
    url = models.URLField(help_text="Link to the PDF, YouTube video, or Article")
    thumbnail_url = models.URLField(default="https://images.unsplash.com/photo-1497366216548-37526070297c")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title
