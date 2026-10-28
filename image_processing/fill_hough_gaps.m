function h = fill_hough_gaps(h,Params)
% Fill frames where hough_fas found no fascicle line in the searched angle
% range (NaN) with the nearest valid value, so the low-pass filter can run.
% When there are no NaN (e.g. GM videos) the signal is returned unchanged.
bad = isnan(h);
if ~any(bad), return; end
if all(bad)
    pr = [15 60];
    if isfield(Params,'houghPennRange'), pr = sort(Params.houghPennRange); end
    error('fill_hough_gaps:noLines', ['No fascicle line found by the Hough transform in any frame ' ...
        '(searched pennation %g-%g deg). Adjust "Hough angle min/max" in the interface ' ...
        '(e.g. ~2-20 deg for tibialis anterior).'], pr(1), pr(2));
end
warning('fill_hough_gaps:filled','Hough: no line in range in %d/%d frames, filled with nearest valid value.', ...
    nnz(bad), numel(bad));
h = fillmissing(h,'nearest');
end
