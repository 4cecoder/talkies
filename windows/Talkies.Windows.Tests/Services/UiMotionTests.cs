using System;
using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public sealed class UiMotionTests
{
    [Fact]
    public void DisabledClientAreaAnimationsRemoveTransitionDuration()
    {
        Assert.Equal(TimeSpan.Zero, UiMotion.GetDuration(TimeSpan.FromMilliseconds(190), animationsEnabled: false));
    }

    [Fact]
    public void EnabledClientAreaAnimationsKeepRequestedTransitionDuration()
    {
        var requested = TimeSpan.FromMilliseconds(190);
        Assert.Equal(requested, UiMotion.GetDuration(requested, animationsEnabled: true));
    }
}
