from django.db import models

class Resource(models.Model):
    # Define the VIP Categories
    CATEGORY_CHOICES = [
        ('GEN', 'General Resource'),
        ('MAG', 'Magazine'),
        ('NEWS', 'Newsletter'),
        ('CLASS', 'Masterclass'),
        ('POD', 'Podcast'),
    ]

    title = models.CharField(max_length=200)
    description = models.TextField()
    url = models.URLField()
    # Add this new field:
    category = models.CharField(max_length=10, choices=CATEGORY_CHOICES, default='GEN')
    # Add a thumbnail for magazines/videos
    thumbnail_url = models.URLField(blank=True, null=True) 
    
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"[{self.get_category_display()}] {self.title}"
