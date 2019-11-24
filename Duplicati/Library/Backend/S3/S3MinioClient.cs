using System;
using System.Collections.Generic;
using System.IO;
using System.Reactive.Linq;
using System.Reactive.Threading.Tasks;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Utility;
using Minio;
using Minio.Exceptions;
using Minio.DataModel;

namespace Duplicati.Library.Backend
{
    public class S3MinioClient : IS3Client
    {
        private static readonly string Logtag = Logging.Log.LogTagFromType<S3MinioClient>();

        private readonly MinioClient m_client;
        private readonly string m_locationConstraint;        

        public S3MinioClient(string awsID, string awsKey, string locationConstraint, 
                string servername, string storageClass, bool useSSL, Dictionary<string, string> options)
        {

            m_locationConstraint = locationConstraint;
            m_client = new MinioClient(
                servername,
                awsID,
                awsKey,
                locationConstraint
            );

            if (useSSL)
            {
                m_client = m_client.WithSSL();
            }
        }

        public void Dispose()
        {
            return;
        }

        public IEnumerable<IFileEntry> ListBucket(string bucketName, string prefix)
        {
            var observable = m_client.ListObjectsAsync(bucketName, prefix, true);

            // TODO: add exception handling
            foreach (var obj in observable.ToEnumerable())
            {
                yield return new Common.IO.FileEntry(
                    obj.Key,
                    (long) obj.Size,
                    Convert.ToDateTime(obj.LastModified),
                    Convert.ToDateTime(obj.LastModified)
                );
            }
        }

        public void AddBucket(string bucketName)
        {
            try
            {
                m_client.MakeBucketAsync(bucketName, m_locationConstraint);
            }
            catch (MinioException e)
            {
                Logging.Log.WriteErrorMessage(Logtag, "ErrorMakingBucketMinio", null,
                    "Error making bucket {0} using Minio: {1}", bucketName, e.ToString());
            }
        }

        public void DeleteObject(string bucketName, string keyName)
        {
            throw new System.NotImplementedException();
        }

        public void RenameFile(string bucketName, string source, string target)
        {
            throw new System.NotImplementedException();
        }

        public void GetFileStream(string bucketName, string keyName, Stream target)
        {
            try
            {
                // Check whether the object exists using statObject().
                // If the object is not found, statObject() throws an exception,
                // else it means that the object exists.
                // Execution is successful.
                m_client.StatObjectAsync(bucketName, keyName).Await();

                // Get input stream to have content of 'my-objectname' from 'my-bucketname'
                m_client.GetObjectAsync(bucketName, keyName,
                    (stream) =>
                    {
                        Utility.Utility.CopyStream(stream, target);
                    }).Await();
            }
            catch (MinioException e)
            {
                Logging.Log.WriteErrorMessage(Logtag, "ErrorGettingObjectMinio", null,
                    "Error getting object {0} to {1} using Minio: {2}",
                    keyName ,bucketName, e.ToString());
            }
            
        }

        public string GetDnsHost()
        {
            throw new System.NotImplementedException();
        }

        public virtual async Task AddFileStreamAsync(string bucketName, string keyName, Stream source, CancellationToken cancelToken)
        {
            try
            {
                await m_client.PutObjectAsync(bucketName,
                    keyName,
                    source,
                    source.Length,
                    "application/octet-stream", cancellationToken: cancelToken);
            }
            catch(MinioException e)
            {
                Logging.Log.WriteErrorMessage(Logtag, "ErrorPuttingObjectMinio", null,
                    "Error putting object {0} to {1} using Minio: {2}",
                    keyName ,bucketName, e.ToString());
            }
        }
    }
}