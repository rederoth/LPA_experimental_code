function withinRadius = isDotWithinCircle(dot, center, radius)
% dots should be defined like this [x, y].
% computes the distance between these points and check whether a point is
% within radius around the dot center.
% useful to decide whether a fixation is within a fixation window.
% by Richard

dist = hypot(dot(1)-center(1), dot(2)-center(2));

if dist < radius
    withinRadius = 1;
else
    withinRadius = 0;
end

end