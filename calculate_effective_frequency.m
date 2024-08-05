function Fe = calculate_effective_frequency(F, T, osig, relo, ondur, dsig, rmode)
    % Generate the aperiodic strobe signal
    [~, Fe, ~] = gen_strobe_aperiodic(F, T, osig, relo, ondur, dsig, rmode);
end
