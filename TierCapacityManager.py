# Placeholder content for TierCapacityManager.py

import random

class TierCapacityManager:
    def __init__(self, gpus):
        self.gpus = gpus
        self.tiers = {}

    def decideTierAndAllocate(self, job):
        # Logic to allocate jobs based on the least-loaded GPU
        available_gpus = [gpu for gpu in self.gpus if gpu['status'] == 'idle']
        if available_gpus:
            selected_gpu = random.choice(available_gpus)
            return selected_gpu['id'], job
        else:
            return None, None

    def updateGPUStatus(self, gpu_id, status):
        # Logic to update GPU status
        for gpu in self.gpus:
            if gpu['id'] == gpu_id:
                gpu['status'] = status
                break
