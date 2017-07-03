import org.sonatype.nexus.repository.Repository;
import org.sonatype.nexus.repository.config.Configuration;

Repository repo = repository.getRepositoryManager().get(args);
Configuration config = repo.getConfiguration();
config.setOnline(true);

repo.stop();
repo.update(config);
repo.start();
