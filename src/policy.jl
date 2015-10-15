abstract SARSOPPolicy <: Policy

# Handles POMDPs
type POMDPPolicy <: SARSOPPolicy
    filename::String
    alphas::Alphas
    POMDPPolicy(filename::String, alphas::Alphas) = new(filename, alphas)
    function POMDPPolicy(filename="out.policy")
        self = new()
        self.filename = filename
        self.alphas = POMDPAlphas(filename)
        return self
    end
end

# Handles MOMDPs
type MOMDPPolicy <: SARSOPPolicy
    filename::String
    alphas::Alphas
    MOMDPPolicy(filename::String, alphas::Alphas) = new(filename, alphas)
    function MOMDPPolicy(filename="out.policy")
        self = new()
        self.filename = filename
        self.alphas = MOMDPAlphas(filename)
        return self
    end
end

function action(policy::POMDPPolicy, b::Belief)
    return action(policy.alphas, b)
end
function action(policy::MOMDPPolicy, b::Belief, x::Int64)
    # for MOMDP
    return action(policy.alphas, b, x)
end