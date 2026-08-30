# ADR-0001: Container Apps over AKS

**Status:** Accepted  
**Date:** 2026-08-29

## Context

The application layer needs a compute host. Options are AKS or Azure Container Apps. The agent itself runs on Foundry Agent Service.

## Decision

Use **Azure Container Apps** for the application layer.

## Rationale

- Scale-to-zero and consumption pricing suit an idle-heavy demo
- Request-based autoscaling without managing node pools
- Smaller ops surface than AKS for this scope

## Consequences

- AKS stays out of scope unless a later bonus (e.g. self-hosted vLLM) needs it
- No AKS module in this repository
