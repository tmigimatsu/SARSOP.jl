"""
    SARSOPSolver

Base solver type for SARSOP. Contains an options dictionary with the following entries:

* 'fast': use fast (but very picky) alternate parser for .pomdp files
* 'randomization': turn on randomization for the sampling algorithm
* 'precision': run ends when target precision is reached
* 'timeout':  [sec] If running time exceeds the specified value, pomdpsol writes out a policy and terminates
* 'memory': [MB] If memory usage exceeds the specified value, pomdpsol writes out a policy and terminates
* 'trial-improvement-factor': temrinates when the gap between bounds reaches this value
* 'policy-interval':  the time interval between two consecutive write-out of policy files
"""
type SARSOPSolver <: Solver

    options::Dict{AbstractString,Any}

    function SARSOPSolver(;
        fast::Bool=false, # Use fast (but very picky) alternate parser for .pomdp files
        randomization::Bool=false, # run ends when target precision is reached
        precison::Float64=DEFAULT_PRECISION, # Turn on randomization for the sampling algorithm.
        timeout::Float64=NaN, # [sec] If running time exceeds the specified value, pomdpsol writes out a policy and terminates
        memory::Float64=NaN, # [MB] If memory usage exceeds the specified value, pomdpsol writes out a policy and terminates
        trial_improvement_factor::Float64=DEFAULT_TRIAL_IMPROVEMENT_FACTOR, 
                    # a trial terminates at a belief when the gap between its upper and lower bound is within 
                    # `improvement_constant` of the current precision at the initial belief
        policy_interval::Float64=NaN # the time interval between two consecutive write-out of policy files; defaults to only exporting at end
        )

        options = Dict{AbstractString,Any}()
        if fast
            options["fast"] = ""
        end
        if randomization
            options["randomization"] = ""
        end
        if !isapprox(precison, DEFAULT_PRECISION)
            options["precision"] = precison 
        end
        if !isnan(timeout)
            options["timeout"] = timeout
        end
        if !isnan(memory)
            options["memory"] = memory
        end
        if !isapprox(trial_improvement_factor, DEFAULT_TRIAL_IMPROVEMENT_FACTOR)
           options["trial-improvement-factor"] = trial_improvement_factor 
        end
        if !isnan(policy_interval)
            options["policy-interval"] = policy_interval
        end

        new(options)
    end
end

"""
    SARSOPPolicy

Abstract policy type - parent of POMDP and MOMDP policy types
"""
abstract SARSOPPolicy <: Policy

"""
    POMDPPolicy

Policy type for POMDPs that contains a reference to the .policy file generated by pomdpsol.
Contains the alpha vectors and the action mapping required to execute a policy.
"""
type POMDPPolicy <: SARSOPPolicy
    filename::AbstractString
    alphas::Alphas
    pomdp::Union{POMDP, SARSOPFile}
    action_map::Vector{Any}
    POMDPPolicy(filename::AbstractString, alphas::Alphas, pomdp::POMDP) = new(filename, alphas, pomdp, Any[])
    function POMDPPolicy(pomdp::POMDP, filename::AbstractString="out.policy")
        self = new()
        self.filename = filename
        self.pomdp = pomdp
        self.alphas = POMDPAlphas()
        return self
    end
    function POMDPPolicy(pomdp::POMDPFile, filename::AbstractString="out.policy")
        self = new()
        self.filename = filename
        self.pomdp = pomdp
        self.alphas = POMDPAlphas()
        return self
    end
end

#=
"""
    MOMDPPolicy

Policy type for MOMDPs that contains a reference to the .policy file generated by pomdpsol.
Contains the alpha vectors and the action mapping required to execute a policy.
"""
type MOMDPPolicy <: SARSOPPolicy
    filename::AbstractString
    alphas::Alphas
    pomdp::POMDP
    action_map::Vector{Any}
    MOMDPPolicy(filename::AbstractString, alphas::Alphas, pomdp) = new(filename, alphas, pomdp, Any[])
    function MOMDPPolicy(filename="out.policy")
        self = new()
        self.filename = filename
        if isfile(filename)
            self.alphas = MOMDPAlphas(filename)
        else
            self.alphas = MOMDPAlphas()
        end
        return self
    end
end
=#


"""
    solve(solver, pomdp, policy)

Runs pomdpsol using the options in 'solver' on 'pomdp', 
and writes out a .policy xml file specified by 'policy'.
"""
function solve(solver::SARSOPSolver, pomdp::SARSOPFile, policy::POMDPPolicy=create_policy(solver, pomdp))
    if isempty(solver.options)
        run(`$EXEC_POMDP_SOL $(pomdp.filename) --output $(policy.filename)`)
    else
        options_list = _get_options_list(solver.options)
        run(`$EXEC_POMDP_SOL $(pomdp.filename) --output $(policy.filename) $options_list`)
    end
    policy.alphas = POMDPAlphas(policy.filename)
    return policy
end

function solve(solver::SARSOPSolver, pomdp::POMDP, policy::POMDPPolicy=create_policy(solver, pomdp))
    pomdp_file = POMDPFile(pomdp)
    if isempty(solver.options)
        run(`$EXEC_POMDP_SOL $(pomdp_file.filename) --output $(policy.filename)`)
    else
        options_list = _get_options_list(solver.options)
        run(`$EXEC_POMDP_SOL $(pomdp_file.filename) --output $(policy.filename) $options_list`)
    end
    policy.alphas = POMDPAlphas(policy.filename)
    return policy
end

#=
# generates a momdp policy file
function solve(solver::SARSOPSolver, pomdp::SARSOPFile, policy::MOMDPPolicy)
    if isempty(solver.options)
        run(`$EXEC_POMDP_SOL $(pomdp.filename) --output $(policy.filename)`)
    else
        options_list = _get_options_list(solver.options)
        run(`$EXEC_POMDP_SOL $(pomdp.filename) --output $(policy.filename) $options_list`)
    end
    policy.alphas = MOMDPAlphas(policy.filename)
end
=#


function load_policy(pomdp::POMDP, file_name::AbstractString)
    alphas = nothing
    if isfile(filename)
        alphas = POMDPAlphas(filename)
    else
        error("Policy file ", file_name, " does not exist")
    end
    policy = POMDPPolicy(pomdp, file_name)  
    policy.alphas = alphas
    return policy
end


"""
    updater(policy::SARSOPPolicy)
Returns the belief updater (DiscreteUpdater) for SARSOP policies.
"""
updater(p::POMDPPolicy) = DiscreteUpdater(p.pomdp)

create_policy(solver::SARSOPSolver, pomdp::Union{POMDP,POMDPFile}, filename::AbstractString="out.policy") = POMDPPolicy(pomdp, filename) 

create_belief(bu::DiscreteUpdater) = DiscreteBelief(n_states(bu.du.pomdp))

updater(p::POMDPPolicy) = DiscreteUpdater(p.pomdp)

function initialize_belief(bu::DiscreteUpdater, initial_state_dist::AbstractDistribution, new_belief::DiscreteBelief=create_belief(bu))
    pomdp = bu.pomdp
    si = 1
    for s in iterator(states(pomdp))
        new_belief[si] = pdf(initial_state_dist, s)
        si += 1
    end
    return new_belief
end


"""
    action(policy, b)

Returns the action index for a blief 'b' according to 'policy' for a POMDP.
"""
function action(policy::POMDPPolicy, b::DiscreteBelief)
    vectors = policy.alphas.alpha_vectors
    actions = policy.alphas.alpha_actions
    utilities = prod(vectors, b) 
    a = actions[indmax(utilities)] + 1
    return a
end


function value(policy::POMDPAlphas, b::DiscreteBelief)
    vectors = policy.alphas.alpha_vectors
    actions = policy.alphas.alpha_actions
    utilities = prod(vectors, b) 
    v =  maximum(utilities)
    return v
end


#=
"""
    action(policy, b, x)

Returns the action index for a blief 'b' according to 'policy' given the fully observable variable index 'x'.
Used for MOMDPs
"""
function action(policy::MOMDPPolicy, b::DiscreteBelief, x::Int64)
    # for MOMDP
    vectors = policy.alphas.alpha_vectors
    actions = policy.alphas.alpha_actions
    states = policy.alphas.observable_states
    o = x - 1 # julia obs: 1-100, sarsop obs: 0-99
    utilities = prod(vectors, b) 
    chunk = actions[find(s -> s == o, states)]
    a = chunk[indmax(utilities[find(s -> s == o, states)])] + 1
    return a
end
=#


function prod(alphas::Matrix{Float64}, b::DiscreteBelief)
    @assert size(alphas, 1) == length(b) "Alpha and belief sizes not equal"
    n = size(alphas, 2)
    util = zeros(n)
    for i = 1:n
        s = 0.0
        for j = 1:length(b)
            s += alphas[j,i]*b[j]
        end
        util[i] = s
    end
    return util
end



"""
    alphas(policy)

Returns the alpha vector matrix `vector length x number vectors`
"""
alphas(policy::SARSOPPolicy) = policy.alphas.alpha_vectors

