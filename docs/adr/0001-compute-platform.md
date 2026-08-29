# ADR-0001: Azure Container Apps over AKS for the agent service

**Status:** Accepted
**Date:** 2026-08-29

## Context

Phase 7 (Deployment) requires running the application on AKS or Azure Container Apps, with the agent itself hosted on Foundry Agent Service. This is a solo portfolio build, not a production workload with existing Kubernetes investment.

## Decision

Use **Azure Container Apps (ACA)** as the compute platform for the application layer that fronts Foundry Agent Service.

## Rationale

- Scale-to-zero and consumption-based pricing matter for a project that will sit mostly idle between demo sessions — AKS has a fixed control-plane and node cost floor even at zero traffic.
- ACA has native, low-effort autoscaling (KEDA-based) on request load, satisfying the Phase 7 autoscaling requirement without writing a HorizontalPodAutoscaler and managing node pools.
- Less infrastructure surface area to secure, patch, and document for a project whose actual value-add is the GenAI platform layer (retrieval, agents, evaluation), not the orchestration layer.
- Matches the brief's default expectation ("AKS if self-hosting any models" — this build is not self-hosting a model in the core path).

## Consequences

- AKS is deferred to the optional bonus challenge: self-hosting an open model on AKS with vLLM, and routing simple queries to it. When that's tackled, AKS is added *alongside* ACA, not instead of it — ACA keeps running the main agent-facing app.
- The Terraform `aks` module in `terraform/modules/` is written but not applied to `dev`/`staging`/`prod` until the bonus challenge is picked up.
- This also means core Kubernetes/Argo CD skills don't get exercised by the main build — noted as a gap; the bonus challenge is the deliberate way to close it.
