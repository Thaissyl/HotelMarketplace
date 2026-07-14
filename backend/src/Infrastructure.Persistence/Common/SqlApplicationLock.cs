using System.Data;
using System.Data.Common;
using System.Globalization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace HotelMarketplace.Infrastructure.Persistence.Common;

internal static class SqlApplicationLock
{
    private const int DefaultTimeoutMilliseconds = 10_000;

    public static async Task<bool> AcquireExclusiveAsync(
        DbContext dbContext,
        string resource,
        CancellationToken cancellationToken)
    {
        DbConnection connection = dbContext.Database.GetDbConnection();
        await using DbCommand command = connection.CreateCommand();
        command.Transaction = dbContext.Database.CurrentTransaction?.GetDbTransaction();
        command.CommandText = """
            DECLARE @lockResult int;
            EXEC @lockResult = sys.sp_getapplock
                @Resource = @resource,
                @LockMode = 'Exclusive',
                @LockOwner = 'Transaction',
                @LockTimeout = @lockTimeout;
            SELECT @lockResult;
            """;

        DbParameter resourceParameter = command.CreateParameter();
        resourceParameter.ParameterName = "@resource";
        resourceParameter.DbType = DbType.String;
        resourceParameter.Value = resource.Length <= 255 ? resource : resource[..255];
        command.Parameters.Add(resourceParameter);

        DbParameter timeoutParameter = command.CreateParameter();
        timeoutParameter.ParameterName = "@lockTimeout";
        timeoutParameter.DbType = DbType.Int32;
        timeoutParameter.Value = DefaultTimeoutMilliseconds;
        command.Parameters.Add(timeoutParameter);

        object? result = await command.ExecuteScalarAsync(cancellationToken);
        int lockResult = Convert.ToInt32(result, CultureInfo.InvariantCulture);

        return lockResult >= 0;
    }

    public static async Task<bool> AcquireRoomLocksAsync(
        DbContext dbContext,
        Guid hotelId,
        IEnumerable<Guid> physicalRoomIds,
        CancellationToken cancellationToken)
    {
        foreach (Guid physicalRoomId in physicalRoomIds.Distinct().OrderBy(id => id))
        {
            bool acquired = await AcquireExclusiveAsync(
                dbContext,
                $"room:{hotelId:N}:{physicalRoomId:N}",
                cancellationToken);

            if (!acquired)
            {
                return false;
            }
        }

        return true;
    }
}
