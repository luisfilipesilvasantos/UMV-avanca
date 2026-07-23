#!/usr/bin/env python

# FASE 0 — Fundação (bloqueante, já identificada)


def allocateSystemVirtual():
    pass


m_totalVirtualCapacity = None


def initialize_virtual_capacity(vram, ram):
    global m_totalVirtualCapacity
    m_totalVirtualCapacity = vram + ram


# Hooks para ligar ao TierManager::decideTierAndAllocate()
def tier_manager_decide_tier_and_allocate():
    pass
