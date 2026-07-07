% ============================================================
% dpp-ac — Answer Set Programming verification layer
% ============================================================
% Design-time formal verification of the dpp-ac access-control policy set.
%
% This program is a FAITHFUL bounded abstraction of the runtime decision
% pipeline (SPARQL rules R01-R10 over the OWL 2 DL + SHACL model). It mirrors
% only the decision-relevant rules:
%   R01 RBAC grant (with the ABAC attribute gate)   -> rbac_grant_*
%   R02 RBAC prohibition                            -> rbac_prohibited
%   R06 ReBAC ownership grant                        -> scenario facts owns/2
%   R07 ReBAC delegation grant                       -> scenario facts deleg/2
%   R08 conflict resolution (deny-overrides)         -> prohibition beats grants
%   R09 final decision (closed-world default-deny)   -> decision/2
% R03 (temporal) and R04 (purpose) are provenance markers that do NOT gate the
% final decision, and R05 duplicates the ABAC gate already inside R01; they are
% therefore outside the decision abstraction (documented in the paper).
%
% Facts are transcribed from the canonical artifacts:
%   ontologies/domain/dpp-roles.ttl            (role class hierarchy)
%   ontologies/domain/dpp-data-categories.ttl  (data-category hierarchy)
%   examples/scenarios/example-policies.ttl     (the eight example policies)
%   examples/knowledge-graphs/built-environment-scenario.ttl (the six scenarios)
% ============================================================

% ------------------------------------------------------------
% ACTIONS
% ------------------------------------------------------------
action(read). action(update). action(delete).

% ------------------------------------------------------------
% ROLE CLASS HIERARCHY  (dpp-roles.ttl)
% concrete operational roles + abstract grouping/representative classes
% ------------------------------------------------------------
role_class(manufacturer). role_class(importer). role_class(distributor).
role_class(auth_rep). role_class(economic_operator).
role_class(msa). role_class(customs). role_class(regulatory_authority).
role_class(maintenance_tech). role_class(service_provider).
role_class(recycler). role_class(consumer).

concrete_role(manufacturer). concrete_role(importer). concrete_role(distributor).
concrete_role(msa). concrete_role(customs). concrete_role(maintenance_tech).
concrete_role(recycler). concrete_role(consumer).

% direct rdfs:subClassOf edges among role classes
subrole(manufacturer, economic_operator).
subrole(importer, economic_operator).
subrole(distributor, economic_operator).
subrole(auth_rep, economic_operator).
subrole(msa, regulatory_authority).
subrole(customs, regulatory_authority).
subrole(maintenance_tech, service_provider).

% reflexive-transitive closure  (rdf:type/rdfs:subClassOf* in R01/R02)
role_sub(R,R) :- role_class(R).
role_sub(R,T) :- subrole(R,S), role_sub(S,T).

% ------------------------------------------------------------
% DATA-CATEGORY HIERARCHY  (dpp-data-categories.ttl)
% ------------------------------------------------------------
category(data_category).
category(product_id). category(env_perf). category(material).
category(supply_chain). category(certification). category(use_maint).
category(end_of_life).
category(carbon). category(energy_eff). category(hazardous).
category(repairability). category(disassembly).

% top-level resource categories used for the exhaustive surface (Tier 1)
tier1(product_id). tier1(env_perf). tier1(material). tier1(supply_chain).
tier1(certification). tier1(use_maint). tier1(end_of_life).

% direct rdfs:subClassOf edges among categories
subcat(product_id, data_category).
subcat(env_perf, data_category).
subcat(material, data_category).
subcat(supply_chain, data_category).
subcat(certification, data_category).
subcat(use_maint, data_category).
subcat(end_of_life, data_category).
subcat(carbon, env_perf).
subcat(energy_eff, env_perf).
subcat(hazardous, material).
subcat(repairability, use_maint).
subcat(disassembly, end_of_life).

% reflexive-transitive closure  (belongsToModule/rdfs:subClassOf* in R01/R02)
cat_sub(C,C) :- category(C).
cat_sub(C,T) :- subcat(C,S), cat_sub(S,T).

% ------------------------------------------------------------
% POLICY SET  (example-policies.ttl) — one policy per concrete role
% policy(PolicyId, RoleClass)
% perm(PolicyId, Action, TargetCategory)
% prohib(PolicyId, Action, TargetCategory)
% constraint(PolicyId, AttributeName)   -- an ABAC attribute gate
% ------------------------------------------------------------

% Policy 1 — Manufacturer: read/update all; prohibit delete of certification
policy(p_manu, manufacturer).
perm(p_manu, read, data_category).
perm(p_manu, update, data_category).
prohib(p_manu, delete, certification).

% Policy 2 — Distributor: read product identification + certification
policy(p_dist, distributor).
perm(p_dist, read, product_id).
perm(p_dist, read, certification).

% Policy 3 — Importer: read all; update supply chain
policy(p_imp, importer).
perm(p_imp, read, data_category).
perm(p_imp, update, supply_chain).

% Policy 4 — Recycler: read end-of-life + material, IF certification valid
policy(p_recy, recycler).
perm(p_recy, read, end_of_life).
perm(p_recy, read, material).
constraint(p_recy, cert_valid).

% Policy 5 — Maintenance Technician: read use/maintenance + repairability, IF trust ok
policy(p_tech, maintenance_tech).
perm(p_tech, read, use_maint).
perm(p_tech, read, repairability).
constraint(p_tech, trust_ok).

% Policy 6 — Consumer: read public data (id, energy efficiency, end-of-life)
policy(p_cons, consumer).
perm(p_cons, read, product_id).
perm(p_cons, read, energy_eff).
perm(p_cons, read, end_of_life).

% Policy 7 — Market Surveillance Authority: read all (purpose = provenance only)
policy(p_msa, msa).
perm(p_msa, read, data_category).

% Policy 8 — Customs Authority: read product identification + certification
policy(p_cust, customs).
perm(p_cust, read, product_id).
perm(p_cust, read, certification).

has_constraint(P) :- constraint(P,_).

% ------------------------------------------------------------
% DECISION SEMANTICS (faithful to R01/R02 + the R08/R09 aggregation)
% ------------------------------------------------------------
% A policy P applies to requester role R iff R is subsumed by P's role class.
applies(P,R) :- policy(P,PRole), role_sub(R,PRole), concrete_role(R).

% permission / prohibition coverage of (action, resource-category)
perm_covers(P,A,C)   :- perm(P,A,T),   cat_sub(C,T), tier1(C), action(A).
prohib_covers(P,A,C) :- prohib(P,A,T), cat_sub(C,T), tier1(C), action(A).

% R01 without an ABAC constraint  -> unconditional RBAC grant
rbac_grant_uncond(R,A,C) :- applies(P,R), perm_covers(P,A,C), not has_constraint(P).
% R01 with an ABAC constraint     -> grant conditional on the attribute gate
rbac_grant_cond(R,A,C)   :- applies(P,R), perm_covers(P,A,C), has_constraint(P).
% R02 prohibition
rbac_prohibited(R,A,C)   :- applies(P,R), prohib_covers(P,A,C).

% Decision surface over concrete roles x actions x Tier-1 categories.
% Priority mirrors R08/R09: prohibition (deny-overrides) > grant > default-deny.
% "conditional" = granted only when the ABAC attribute gate is satisfied
% (these are exactly the attribute/purpose-gated cells, e.g. Fig. access matrix R*).
surface(R,A,C, deny)        :- concrete_role(R), action(A), tier1(C), rbac_prohibited(R,A,C).
surface(R,A,C, grant)       :- concrete_role(R), action(A), tier1(C),
                               not rbac_prohibited(R,A,C), rbac_grant_uncond(R,A,C).
surface(R,A,C, conditional) :- concrete_role(R), action(A), tier1(C),
                               not rbac_prohibited(R,A,C), not rbac_grant_uncond(R,A,C),
                               rbac_grant_cond(R,A,C).
surface(R,A,C, deny)        :- concrete_role(R), action(A), tier1(C),
                               not rbac_prohibited(R,A,C), not rbac_grant_uncond(R,A,C),
                               not rbac_grant_cond(R,A,C).

% ------------------------------------------------------------
% PROPERTY 1 — CONFLICT-FREENESS
% A (role, action, category) that is simultaneously granted and prohibited
% would force the deny-overrides rule R08. Enumerate any such conflicts.
% ------------------------------------------------------------
conflict(R,A,C) :- rbac_grant_uncond(R,A,C), rbac_prohibited(R,A,C).
conflict(R,A,C) :- rbac_grant_cond(R,A,C),   rbac_prohibited(R,A,C).
conflict_exists :- conflict(_,_,_).

% ------------------------------------------------------------
% PROPERTY 2 — DECISION DETERMINISM / TOTALITY
% Every (role, action, category) in the bounded space must receive exactly
% one surface outcome. multi_outcome flags any violation (expected: none).
% ------------------------------------------------------------
multi_outcome(R,A,C) :- surface(R,A,C,O1), surface(R,A,C,O2), O1 != O2.
undecided(R,A,C) :- concrete_role(R), action(A), tier1(C), not has_surface(R,A,C).
has_surface(R,A,C) :- surface(R,A,C,_).
nondeterministic :- multi_outcome(_,_,_).
incomplete :- undecided(_,_,_).

% ------------------------------------------------------------
% PROPERTY 3 — ROLE / POLICY COVERAGE
% Which role classes obtain at least one grant path. Uncovered classes are
% expected to be exactly the four abstract classes with no bound policy.
% ------------------------------------------------------------
role_has_grant(R) :- rbac_grant_uncond(R,_,_).
role_has_grant(R) :- rbac_grant_cond(R,_,_).
role_uncovered(R) :- role_class(R), not role_has_grant(R).

% ============================================================
% FAITHFULNESS GATE — reproduce the six built-environment scenarios
% sreq(Id, Role, Action, Category)   the request
% owns(Id)      resource is owned by the requester   (R06)
% deleg(Id)     an active delegation covers the request (R07)
% attr_sat(Id)  the request satisfies the policy's ABAC attribute gate (R01/R05)
% ============================================================
sreq(s1, manufacturer,     read, material).      owns(s1).
sreq(s2, msa,              read, supply_chain).
sreq(s3, consumer,         read, supply_chain).
sreq(s4, maintenance_tech, read, use_maint).     deleg(s4).
sreq(s5, recycler,         read, end_of_life).   % certification invalid -> gate fails
sreq(s6, recycler,         read, end_of_life).   attr_sat(s6).

expected(s1, grant). expected(s2, grant). expected(s3, deny).
expected(s4, grant). expected(s5, deny).  expected(s6, grant).

% concrete decision, faithful to R08/R09 (prohibition first, then any grant path)
s_deny_override(Q) :- sreq(Q,R,A,C), rbac_prohibited(R,A,C).
s_grant(Q) :- sreq(Q,R,A,C), not s_deny_override(Q), rbac_grant_uncond(R,A,C).
s_grant(Q) :- sreq(Q,R,A,C), not s_deny_override(Q), rbac_grant_cond(R,A,C), attr_sat(Q).
s_grant(Q) :- sreq(Q,_,_,_), not s_deny_override(Q), owns(Q).
s_grant(Q) :- sreq(Q,_,_,_), not s_deny_override(Q), deleg(Q).
decision(Q, grant) :- s_grant(Q).
decision(Q, deny)  :- sreq(Q,_,_,_), not s_grant(Q).

% cross-check against the expected outcomes
scenario_mismatch(Q) :- expected(Q,E), decision(Q,D), D != E.
faithful :- not has_mismatch.
has_mismatch :- scenario_mismatch(_).

grant_count(N) :- N = #count { Q : decision(Q, grant) }.
deny_count(N)  :- N = #count { Q : decision(Q, deny) }.

#show surface/4.
#show conflict/3.
#show role_uncovered/1.
#show multi_outcome/3.
#show undecided/3.
#show decision/2.
#show scenario_mismatch/1.
#show grant_count/1.
#show deny_count/1.
