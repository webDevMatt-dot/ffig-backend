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
    url = models.URLField(blank=True, null=True) # Allow null if we have a file
    # PDF or other resource file
    file = models.FileField(upload_to='resources/files/', blank=True, null=True)
    
    category = models.CharField(max_length=10, choices=CATEGORY_CHOICES, default='GEN')
    # Add a thumbnail for magazines/videos
    thumbnail = models.ImageField(upload_to='resources/thumbnails/', blank=True, null=True)
    thumbnail_url = models.URLField(blank=True, null=True) 
    
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True) # Soft Delete / Deactivation

    def __str__(self):
        return f"[{self.get_category_display()}] {self.title}"

class ResourceImage(models.Model):
    resource = models.ForeignKey(Resource, related_name='images', on_delete=models.CASCADE)
    image = models.ImageField(upload_to='resources/gallery/')
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Image for {self.resource.title}"
