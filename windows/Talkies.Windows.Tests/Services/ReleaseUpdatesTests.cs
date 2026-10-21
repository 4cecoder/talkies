using Talkies.Windows.Services;
using Xunit;

namespace Talkies.Windows.Tests.Services;

public class ReleaseUpdatesTests
{
    [Theory]
    [InlineData("0.1.10", "0.1.9", 1)]
    [InlineData("1.0.0", "1.0.1", -1)]
    [InlineData("1.2", "1.2.0", 0)]
    public void Compare_UsesNumericComponents(string left, string right, int expected) =>
        Assert.Equal(expected, ReleaseUpdates.Compare(left, right));
}
